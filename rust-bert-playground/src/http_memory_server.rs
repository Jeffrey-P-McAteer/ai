
use crate::*;

use std::io::Read;
use std::collections::HashMap;
use std::sync::{Arc, RwLock};

use hyper::server::{Server, Request, Response};
use hyper::method::Method;
use websocket::Message;
use websocket::sync::server::upgrade::IntoWs;
use websocket::sync::server::upgrade::HyperRequest;

use include_dir::{include_dir, Dir};

use lazy_static::lazy_static;


static WWW_FILES: Dir<'_> = include_dir!("src/www");

lazy_static!{
  // Maps doc name => doc text (does not store originals like .pdf formats)
  static ref QUERY_DOCUMENTS: Arc<RwLock<HashMap<String, String>>> = {
      Arc::new(RwLock::new(HashMap::new()))
  };

  // websocket threads poll this and send new messages to all clients.
  static ref MESSAGES_TO_WEBSOCKETS: Arc<RwLock<Vec<String>>> = {
      Arc::new(RwLock::new(Vec::new()))
  };

  static ref QUESTIONS_TO_MODEL: Arc<RwLock<Vec<String>>> = {
      Arc::new(RwLock::new(Vec::new()))
  };


}

pub fn broadcast_to_websockets(msg: &str) {
  loop {
      if let Ok(mut messages_to_ws_ref) = MESSAGES_TO_WEBSOCKETS.write() {
        messages_to_ws_ref.push(
          msg.to_string()
        );
        break;
      }
      else {
        std::thread::sleep( std::time::Duration::from_millis(5) );
      }
    }
}

pub fn question_answering_thread() {
  println!("Question Answering thread spawned...");

  let mut qa_model = QuestionAnsweringModel::new(Default::default()).expect("No models available!");

  let mut last_question_i = 0;

  loop {
    std::thread::sleep( std::time::Duration::from_millis(50) );
    if let Ok(questions_to_model) = QUESTIONS_TO_MODEL.read() {
      if questions_to_model.len() > last_question_i {
        
        // Collect context real fast
        let mut context_str = String::new();
        if let Ok(query_documents) = QUERY_DOCUMENTS.read() {
          for document_txt in query_documents.values() {
            context_str += document_txt;
            context_str += "\n";
          }
        }
        let num_words = words_count::count(&context_str);
        
        println!("Using {}-word context to answer question...", num_words.words);

        broadcast_to_websockets(&format!("Using {}-word context to answer question...", num_words.words));

        for question_to_ask_i in last_question_i..questions_to_model.len() {
          let question_txt = String::new();
          let question_txt = questions_to_model.get(question_to_ask_i).unwrap_or(&question_txt);
          if question_txt.len() > 0 {
            println!("Asking {}", question_txt);
            let answers = qa_model.predict(
              &[
                QaInput { question:question_txt.clone(), context:context_str.clone() }
              ],
              // Number of answes to give
              5,
              // Number of answer quality steps
              //4096
              256,
            );
            for answer in answers {
              for a in answer {
                let answer_txt = format!("{:?}", a.answer);
                let ui_resp = format!("{} {}% => {}", question_txt, (a.score * 100.0).round() / 100.0, answer_txt );
                
                println!("{}", ui_resp);

                broadcast_to_websockets(&ui_resp);

              }
            }
          }
        }
        last_question_i = questions_to_model.len();
      }
    }
  }

}


pub fn run_server(ip_and_port: String) {

  println!("Spawning server on http://{}", ip_and_port);

  std::thread::spawn(|| {
    question_answering_thread();
  });

  let num_threads = 8; // Limits max websocket connections available b/c we consume an entire thread for those

  Server::http(&ip_and_port).unwrap().handle_threads(move |req: Request, res: Response| {
    let query_documents_arc = QUERY_DOCUMENTS.clone();
    let messages_to_websockets_arc = MESSAGES_TO_WEBSOCKETS.clone();
      match HyperRequest(req).into_ws() {
          Ok(upgrade) => {
              // `accept` sends a successful handshake, no need to worry about res
              let mut client = match upgrade.accept() {
                  Ok(c) => c,
                  Err(_) => panic!(),
              };

              println!("Got websocket client!");

              let mut last_msg_i = 0;
              let mut close_client_conn = false;
              loop {
                std::thread::sleep( std::time::Duration::from_millis(50) );
                if let Ok(messages_to_ws_ref) = messages_to_websockets_arc.read() {
                  if messages_to_ws_ref.len() > last_msg_i {
                    // Send messages last_msg_i -> messages_to_ws_ref.len()-1
                    for msg_to_send_i in last_msg_i..messages_to_ws_ref.len() {
                      let res = client.send_message(&Message::text(
                        messages_to_ws_ref.get(msg_to_send_i).unwrap_or(&String::new())
                      ));
                      if let Err(e) = res {
                        println!("Websocket client error {:?}", e);
                        close_client_conn = true;
                      }
                    }
                    last_msg_i = messages_to_ws_ref.len();
                  }
                }
                if close_client_conn {
                  break;
                }
              }

          },

          Err((mut request, _err)) => { // Not a websocket conn

              if request.method == Method::Post {
                let req_uri = format!("{}", request.uri);
                let mut req_uri = &req_uri[1..req_uri.len()];
                
                println!("Received POST {}", req_uri);
                if req_uri == "add-document" {
                  let mut added_a_doc = false;
                  match multipart::server::Multipart::from_request(request) {
                    Ok(mut multipart_req) => {

                      for _multipart_i in 0..100 { // Any max number will do > than what someone will feed in in a single form submission.
                        if let Ok(Some(mut multipart_field)) = multipart_req.read_entry() {
                          let file_name = multipart_field.headers.filename.unwrap_or("UNKNOWN".to_string());
                          
                          let mut file_posted_bytes: Vec<u8> = vec![];
                          multipart_field.data.read_to_end(&mut file_posted_bytes).expect("Could not read POSTed data");
                          println!("Got {} multipart file bytes from {}", file_posted_bytes.len(), &file_name );

                          let mut document_string_contents = String::new();
                          if file_name.ends_with("txt") || file_name.ends_with("TXT") {
                            document_string_contents = String::from_utf8_lossy(&file_posted_bytes).to_string();
                          }
                          else if file_name.ends_with("pdf") || file_name.ends_with("PDF") {
                            if let Ok(pdf_text) = pdf_extract::extract_text_from_mem(&file_posted_bytes) {
                              document_string_contents = pdf_text;
                            }
                          }
                          else {
                            println!("Unknown file name {}, does not look like PDF or TXT!", file_name);
                          }

                          let num_words = words_count::count(&document_string_contents);
                          println!("Read {} words from {}", num_words.words, file_name);

                          broadcast_to_websockets(&format!("Read {} words from {}", num_words.words, file_name));

                          if num_words.words > 0 {
                              added_a_doc = true;
                            }

                          for _attempt_i in 0..100 { // try 100 times (up to 1s) to get a write mutex lock
                            if let Ok(mut query_documents_ref) = query_documents_arc.write() {
                              query_documents_ref.insert(
                                file_name.clone(),
                                document_string_contents
                              );
                              break;
                            }
                            else {
                              std::thread::sleep( std::time::Duration::from_millis(10) ); // Wait for someone else to unlock the mutex
                            }
                          }

                        }
                      }

                    },
                    Err(_e) => {
                      println!("Error, request is not multipart!");
                    }
                  }
                  if !added_a_doc {
                    // Must have been a clear command, clear all docs
                    if let Ok(mut query_documents_ref) = query_documents_arc.write() {
                      println!("Clearing {} documents...", query_documents_ref.len() );
                      broadcast_to_websockets(&format!("Clearing {} documents...", query_documents_ref.len() ));
                      query_documents_ref.clear();
                    }
                  }
                }
                else if req_uri == "ask-question" {
                  let mut posted_bytes: Vec<u8> = vec![];
                  request.read_to_end(&mut posted_bytes).expect("Could not read POSTed data");
                  let question_urlencoded = String::from_utf8_lossy(&posted_bytes).to_string();
                  let question_urlencoded = urldecode::decode(question_urlencoded);
                  let question_urlencoded = question_urlencoded.replace("+", " ");
                  let question_urlencoded = if question_urlencoded.len() > 2 { &question_urlencoded[2..] } else { &question_urlencoded[..] };

                  let question_info = format!("> {}", question_urlencoded);
                  println!("{}", question_info);

                  for _i in 0..100 {
                    if let Ok(mut questions_to_model) = QUESTIONS_TO_MODEL.write() {
                      questions_to_model.push(
                        question_urlencoded.to_string()
                      );
                      break;
                    }
                    else {
                      std::thread::sleep( std::time::Duration::from_millis(5) );
                    }
                  }

                  broadcast_to_websockets(&question_info);

                }
                else {
                  let mut posted_bytes: Vec<u8> = vec![];
                  request.read_to_end(&mut posted_bytes).expect("Could not read POSTed data");
                  if posted_bytes.len() < 256 {
                    println!("Unknown POST read {} bytes: {:?}", posted_bytes.len(), &posted_bytes);
                  }
                  else {
                    println!("Unknown POST read {} bytes: [omitted]", posted_bytes.len());
                  }
                }

              }
              else {
                let req_uri = format!("{}", request.uri);
                let mut req_uri = &req_uri[1..req_uri.len()];
                if req_uri.len() < 1 {
                  req_uri = "index.html";
                }
                if let Some(www_file) = WWW_FILES.get_file( req_uri ) {
                  println!("Serving {}", req_uri);
                  res.send( www_file.contents() ).unwrap();
                }
                else {
                  let err_msg = format!("Error, cannot find {}", req_uri);
                  println!("{}", &err_msg);
                  res.send( &err_msg.into_bytes() ).unwrap();
                }
              }

          },
      };
  }, num_threads)
  .unwrap();

}