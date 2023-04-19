
use std::env;

use rust_bert::pipelines::question_answering::{QaInput, QuestionAnsweringModel};
use elapsed;
use ansi_term;

fn main() {
  env::set_var("RUSTBERT_CACHE", "/j/infra/ai/ai-disk/rust-bert-model-cache");
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

//     let context = r#"
//       Arch Linux is a fun operating system.
//       Linus Torvalds wrote the Linux kernel.
//       Arch Linux is based on the Linux kernel.
//       Ice cream is cold.
//       Ice cream is tasty.
// "#.to_string();
    
    let mut context = String::new();
    // Context is built by reading from the directory given in arg[1]

    let walker = globwalk::GlobWalkerBuilder::from_patterns(directory, &["*.{pdf,PDF}"])
      .max_depth(12)
      .follow_links(true)
      .build()
      .expect("Could not build PDF walker!")
      .into_iter()
      .filter_map(Result::ok);

    for pdf_file in walker {
      println!("Reading {:?}", pdf_file);
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

    // let questions = [
    //   "Who helped write Arch Linux?",
    //   "Does the linux kernel use Arch Linux?",
    //   "Are cold things tasty?",
    //   "Why are cold things tasty?",
    // ];

    // for question_ref in questions {
    //   let question = question_ref.to_string();
    //   let context = context.clone();
    //   let answers = qa_model.predict(&[QaInput { question, context }], 1, 32);
    //   let question_txt = format!("{:?}", question_ref.to_string());
    //   let answer_txt = format!("{:?}", answers[0][0].answer);
    //   println!("{} => {}", question_txt, bold_style.paint(&answer_txt) );
    // }

    println!("Computing answers...");
    let question_copy = question.clone();
    let answers = qa_model.predict(&[QaInput { question, context }], 1, 32);
    for answer in answers {
      for a in answer {
        let answer_txt = format!("{:?}", a.answer);
        println!("{} => {}", question_copy, bold_style.paint(answer_txt) );
      }
    }

  });
  println!("Finished execution in {}", elapsed);

}



