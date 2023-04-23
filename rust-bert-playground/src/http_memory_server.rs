
use crate::*;

use std::io::Read;

use hyper::server::{Server, Request, Response};
use hyper::method::Method;
use websocket::Message;
use websocket::sync::server::upgrade::IntoWs;
use websocket::sync::server::upgrade::HyperRequest;

use include_dir::{include_dir, Dir};

static WWW_FILES: Dir<'_> = include_dir!("src/www");

pub fn run_server(ip_and_port: String) {

  println!("Spawning server on http://{}", ip_and_port);

  Server::http(&ip_and_port).unwrap().handle(move |req: Request, res: Response| {
      match HyperRequest(req).into_ws() {
          Ok(upgrade) => {
              // `accept` sends a successful handshake, no need to worry about res
              let mut client = match upgrade.accept() {
                  Ok(c) => c,
                  Err(_) => panic!(),
              };

              client.send_message(&Message::text("its free real estate"));
          },

          Err((mut request, err)) => {
              if request.method == Method::Post {
                let req_uri = format!("{}", request.uri);
                let mut req_uri = &req_uri[1..req_uri.len()];
                
                println!("TODO handle POST to {}", req_uri);
                if req_uri == "add-document" {
                  match multipart::server::Multipart::from_request(request) {
                    Ok(mut multipart_req) => {
                      let mut file_posted_bytes: Vec<u8> = vec![];
                      if let Ok(Some(mut multipart_field)) = multipart_req.read_entry() {
                        multipart_field.data.read_to_end(&mut file_posted_bytes).expect("Could not read POSTed data");
                      }
                      println!("Got {} multipart file bytes", file_posted_bytes.len() );
                      
                    },
                    Err(e) => {
                      println!("Error, request is not multipart!");
                    }
                  }
                }
                else {
                  let mut posted_bytes: Vec<u8> = vec![];
                  request.read_to_end(&mut posted_bytes).expect("Could not read POSTed data");
                  if posted_bytes.len() < 256 {
                    println!("Read {} bytes: {:?}", posted_bytes.len(), &posted_bytes);
                  }
                  else {
                    println!("Read {} bytes: [omitted]", posted_bytes.len());
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
  })
  .unwrap();

}