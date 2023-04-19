
use std::env;

use rust_bert::pipelines::question_answering::{QaInput, QuestionAnsweringModel};
use elapsed;

fn main() {
  env::set_var("RUSTBERT_CACHE", "/j/infra/ai/ai-disk/rust-bert-model-cache");

  elapsed::measure_time(|| {
    let qa_model = QuestionAnsweringModel::new(Default::default()).expect("No models available!");

    // let question = String::from("Where does Amy live ?");
    // let context = String::from("Amy lives in Amsterdam");

    let question = String::from("Who helped write Arch Linux?");
    let context = String::from("Arch Linux is a fun operating system. Linus Torvalds wrote the Linux kernel. Arch Linux is based on the Linux kernel.");

    let answers = qa_model.predict(&[QaInput { question, context }], 1, 32);

    println!("{:?}", answers);

  });

}



