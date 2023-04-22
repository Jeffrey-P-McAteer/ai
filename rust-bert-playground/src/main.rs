
use std::env;
use std::path::Path;

use rust_bert::pipelines::question_answering::{QaInput, QuestionAnsweringModel};
use elapsed;
use ansi_term;

fn main() {
  let mut rustbert_cache_dir = String::from(
    "./target/rust-bert-model-cache"
  );

  if let Ok(env_rustbert_cache_dir) = env::var("RUSTBERT_CACHE") {
    rustbert_cache_dir = env_rustbert_cache_dir.clone();
  }

  // idiot-proof cache dir test first
  if !Path::new(&rustbert_cache_dir).is_dir() && rustbert_cache_dir.contains("target") {
    eprintln!(r#"WARNING: the directory specified by your environment variable[1] "RUSTBERT_CACHE" (or default directory) {:?} does not exist!
Creating the cache directory because we see "target" in the path..
"#, &rustbert_cache_dir);
    if let Err(e) = std::fs::create_dir_all(&rustbert_cache_dir) {
      eprintln!("");
      eprintln!(r#"WARNING: Could not create {:?}, error - {:?} "#, &rustbert_cache_dir, e);
      eprintln!("");
    }
  }
  
  println!("rustbert_cache_dir = {}", &rustbert_cache_dir);
  env::set_var("RUSTBERT_CACHE", &rustbert_cache_dir);

  if !Path::new(&rustbert_cache_dir).is_dir() {
    eprintln!(r#"Error: the directory specified by your environment variable[1] "RUSTBERT_CACHE" (or default directory) {:?} does not exist!

You must create a directory and set the environment variable "RUSTBERT_CACHE" to it before running rust-bert-playground[.exe].

During the first run the BERT language model will be downloaded here.

"#, std::fs::canonicalize(&rustbert_cache_dir) );
    std::process::exit(1);
  }

  let args: Vec<String> = env::args().collect();

  println!("args = {:?}", &args);

  if args.len() < 2 {
    println!(r#"Usage:
      rust-bert-playground ./directory/of/documents "What color is the sky?"
"#);
    std::process::exit(1);
  }

  let directory = args[1].clone();
  let question = args[2].clone();

  let (elapsed, _sum) = elapsed::measure_time(|| {
    let bold_style = ansi_term::Style::new().bold();

    let qa_model = QuestionAnsweringModel::new(Default::default()).expect("No models available!");

    let mut context = String::new();
    // Context is built by reading from the directory given in arg[1]

    let walker = globwalk::GlobWalkerBuilder::from_patterns(directory, &["*.{pdf,PDF}", "*.{txt,TXT}"])
      .max_depth(12)
      .follow_links(true)
      .build()
      .expect("Could not build PDF walker!")
      .into_iter()
      .filter_map(Result::ok);

    for any_file in walker {
      if any_file.file_name().to_string_lossy().ends_with("pdf") || any_file.file_name().to_string_lossy().ends_with("PDF") {
        let pdf_file = any_file;
        println!("Reading PDF file {:?}", pdf_file);
        if let Ok(bytes) = std::fs::read( pdf_file.path() ) {
          match pdf_extract::extract_text_from_mem(&bytes) {
            Ok(pdf_text) => {
              println!("Read {} characters!", pdf_text.len());
              context += &pdf_text;
              context += "\n";
            }
            Err(e) => {
              eprintln!("Error: {:?}", e);
            }
          }
        }
      }
      else if any_file.file_name().to_string_lossy().ends_with("txt") || any_file.file_name().to_string_lossy().ends_with("TXT") {
        let txt_file = any_file;
        println!("Reading TXT file {:?}", txt_file);
        if let Ok(bytes) = std::fs::read( txt_file.path() ) {
          match std::str::from_utf8(&bytes) {
            Ok(txt_text) => {
              println!("Read {} characters!", txt_text.len());
              context += &txt_text;
              context += "\n";
            },
            Err(e) => {
              eprintln!("Error: {:?}", e);
              eprintln!("Using lossy bytes... (invalid utf-8 text will be decoded as junk utf-8 codes)");
              let txt_text = String::from_utf8_lossy(&bytes);
              println!("Read {} (possibly junk nonsense) characters!", txt_text.len());
              context += &txt_text;
              context += "\n";
            }
          }
        }
      }
      else {
        println!("Ignoring unknown file {:?}", any_file);
      }
    }

    println!("Computing answers...");
    let question_copy = question.clone();
    let answers = qa_model.predict(&[QaInput { question, context }], 5,  4096);
    for answer in answers {
      for a in answer {
        let answer_txt = format!("{:?}", a.answer);
        println!("{} {}% => {}", question_copy, (a.score * 100.0).round() / 100.0, bold_style.paint(answer_txt) );
      }
    }

  });
  println!("Finished execution in {}", elapsed);

}



