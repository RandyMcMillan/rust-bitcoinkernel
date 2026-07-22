use bitcoinkernel::prelude::*;
use bitcoinkernel::{Block, ChainParams, ChainType, Transaction};

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

#[derive(uniffi::Record)]
pub struct NetworkSummary {
    pub name: String,
    pub chain_type: String,
    pub description: String,
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

#[uniffi::export]
pub fn network_summary(network: String) -> Option<NetworkSummary> {
    let chain_type = parse_chain_type(&network)?;
    let _chain_params = ChainParams::new(chain_type);
    let name = display_name(chain_type).to_string();

    Some(NetworkSummary {
        name: name.clone(),
        chain_type: format!("{chain_type:?}"),
        description: format!("{name} is ready for Rust-backed chainstate setup."),
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

fn parse_chain_type(network: &str) -> Option<ChainType> {
    match network.trim().to_ascii_lowercase().as_str() {
        "mainnet" => Some(ChainType::Mainnet),
        "testnet" => Some(ChainType::Testnet),
        "testnet4" => Some(ChainType::Testnet4),
        "signet" => Some(ChainType::Signet),
        "regtest" => Some(ChainType::Regtest),
        _ => None,
    }
}

fn display_name(chain_type: ChainType) -> &'static str {
    match chain_type {
        ChainType::Mainnet => "Mainnet",
        ChainType::Testnet => "Testnet",
        ChainType::Testnet4 => "Testnet4",
        ChainType::Signet => "Signet",
        ChainType::Regtest => "Regtest",
    }
}
