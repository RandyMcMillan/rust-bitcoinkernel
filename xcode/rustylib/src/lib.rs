use bitcoinkernel::prelude::*;
use bitcoinkernel::{Block, Transaction};

uniffi::setup_scaffolding!();

#[derive(uniffi::Record)]
pub struct TransactionSummary {
    pub txid: String,
    pub input_count: u64,
    pub output_count: u64,
    pub serialized_len: u64,
}

#[derive(uniffi::Record)]
pub struct BlockSummary {
    pub block_hash: String,
    pub transaction_count: u64,
    pub serialized_len: u64,
    pub coinbase_txid: String,
}

#[uniffi::export]
fn rust_hello() -> String {
    "Hello from Rust!".to_string()
}

#[uniffi::export]
pub fn rust_add(a: u32, b: u32) -> u32 {
    a + b
}

#[uniffi::export]
pub fn transaction_summary_hex(raw_hex: String) -> Option<TransactionSummary> {
    let transaction = decode_transaction(&raw_hex)?;
    let serialized_len = transaction.consensus_encode().ok()?.len() as u64;

    Some(TransactionSummary {
        txid: transaction.txid().to_string(),
        input_count: transaction.input_count() as u64,
        output_count: transaction.output_count() as u64,
        serialized_len,
    })
}

#[uniffi::export]
pub fn block_summary_hex(raw_hex: String) -> Option<BlockSummary> {
    let block = decode_block(&raw_hex)?;
    let serialized_len = block.consensus_encode().ok()?.len() as u64;
    let coinbase_txid = block.transaction(0).ok()?.txid().to_string();

    Some(BlockSummary {
        block_hash: block.hash().to_string(),
        transaction_count: block.transaction_count() as u64,
        serialized_len,
        coinbase_txid,
    })
}

fn decode_transaction(raw_hex: &str) -> Option<Transaction> {
    let bytes = decode_hex(raw_hex)?;
    Transaction::new(&bytes).ok()
}

fn decode_block(raw_hex: &str) -> Option<Block> {
    let bytes = decode_hex(raw_hex)?;
    Block::new(&bytes).ok()
}

fn decode_hex(raw_hex: &str) -> Option<Vec<u8>> {
    let compact: String = raw_hex.chars().filter(|c| !c.is_whitespace()).collect();
    hex::decode(compact).ok()
}
