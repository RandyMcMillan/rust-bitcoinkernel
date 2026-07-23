use bitcoinkernel::prelude::*;
use bitcoinkernel::{
    verify, Block, ChainParams, ChainType, ChainstateManager, ContextBuilder,
    PrecomputedTransactionData, Transaction, TxCheckResult, VERIFY_ALL,
};
use std::{
    collections::HashMap,
    env,
    fs,
    path::PathBuf,
    sync::{Arc, Mutex, OnceLock},
};

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

#[derive(uniffi::Record)]
pub struct TransactionInputSummary {
    pub txid: String,
    pub vout: u64,
    pub sequence: u64,
    pub is_coinbase: bool,
}

#[derive(uniffi::Record)]
pub struct TransactionOutputSummary {
    pub index: u64,
    pub value: i64,
    pub script_pubkey_hex: String,
}

#[derive(uniffi::Record)]
pub struct TransactionRelations {
    pub txid: String,
    pub input_count: u64,
    pub output_count: u64,
    pub serialized_len: u64,
    pub inputs: Vec<TransactionInputSummary>,
    pub outputs: Vec<TransactionOutputSummary>,
}

#[derive(uniffi::Record)]
pub struct TransactionValidationSummary {
    pub txid: String,
    pub is_valid: bool,
    pub validation_result: String,
    pub message: String,
    pub input_count: u64,
    pub output_count: u64,
    pub serialized_len: u64,
}

#[derive(uniffi::Record)]
pub struct TransactionInputValidationSummary {
    pub spending_txid: String,
    pub previous_txid: String,
    pub input_index: u64,
    pub previous_vout: u64,
    pub previous_output_value: i64,
    pub is_valid: bool,
    pub validation_result: String,
    pub message: String,
}

#[derive(uniffi::Record)]
pub struct LocalNodeSummary {
    pub network: String,
    pub chain_type: String,
    pub data_dir: String,
    pub blocks_dir: String,
    pub is_ready: bool,
    pub message: String,
}

struct LocalNodeRuntime {
    _context: bitcoinkernel::Context,
    _chainman: ChainstateManager,
}

static LOCAL_NODE_CACHE: OnceLock<Mutex<HashMap<String, Arc<LocalNodeRuntime>>>> = OnceLock::new();

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
pub fn transaction_relations_hex(raw_hex: String) -> Option<TransactionRelations> {
    let transaction = decode_transaction(&raw_hex)?;
    let serialized_len = transaction.consensus_encode().ok()?.len() as u64;

    let inputs = transaction
        .inputs()
        .map(|input| {
            let outpoint = input.outpoint();
            TransactionInputSummary {
                txid: outpoint.txid().to_string(),
                vout: outpoint.index() as u64,
                sequence: input.sequence() as u64,
                is_coinbase: outpoint.is_null(),
            }
        })
        .collect();

    let outputs = transaction
        .outputs()
        .enumerate()
        .map(|(index, output)| TransactionOutputSummary {
            index: index as u64,
            value: output.value(),
            script_pubkey_hex: hex::encode(output.script_pubkey().to_bytes()),
        })
        .collect();

    Some(TransactionRelations {
        txid: transaction.txid().to_string(),
        input_count: transaction.input_count() as u64,
        output_count: transaction.output_count() as u64,
        serialized_len,
        inputs,
        outputs,
    })
}

#[uniffi::export]
pub fn transaction_validation_hex(raw_hex: String) -> Option<TransactionValidationSummary> {
    let transaction = decode_transaction(&raw_hex)?;
    let serialized_len = transaction.consensus_encode().ok()?.len() as u64;
    let txid = transaction.txid().to_string();

    let (is_valid, validation_result, message) = match transaction.check() {
        TxCheckResult::Valid => (
            true,
            "Valid".to_string(),
            "Rust consensus checks passed.".to_string(),
        ),
        TxCheckResult::Invalid(result) => {
            let validation_result = format!("{result:?}");
            (
                false,
                validation_result.clone(),
                format!("Rust consensus checks failed: {validation_result}"),
            )
        }
    };

    Some(TransactionValidationSummary {
        txid,
        is_valid,
        validation_result,
        message,
        input_count: transaction.input_count() as u64,
        output_count: transaction.output_count() as u64,
        serialized_len,
    })
}

#[uniffi::export]
pub fn transaction_input_validation_hex(
    spending_raw_hex: String,
    previous_raw_hex: String,
    input_index: u64,
) -> Option<TransactionInputValidationSummary> {
    let spending_transaction = decode_transaction(&spending_raw_hex)?;
    let previous_transaction = decode_transaction(&previous_raw_hex)?;

    let spending_txid = spending_transaction.txid().to_string();
    let previous_txid = previous_transaction.txid().to_string();
    let input_index = input_index as usize;

    let input = spending_transaction.input(input_index).ok()?;
    let outpoint = input.outpoint();
    let previous_vout = outpoint.index() as usize;
    let previous_output = previous_transaction.output(previous_vout).ok()?;

    let spent_outputs = vec![previous_output];
    let precomputed_txdata =
        PrecomputedTransactionData::new(&spending_transaction, &spent_outputs).ok()?;

    let previous_output_value = previous_output.value();
    let script_pubkey = previous_output.script_pubkey();
    let verification = verify(
        &script_pubkey,
        Some(previous_output_value),
        &spending_transaction,
        input_index,
        Some(VERIFY_ALL),
        &precomputed_txdata,
    );

    let (is_valid, validation_result, message) = match verification {
        Ok(()) => (
            true,
            "Valid".to_string(),
            "Rust spend verification passed.".to_string(),
        ),
        Err(error) => {
            let validation_result = format!("{error}");
            (
                false,
                validation_result.clone(),
                format!("Rust spend verification failed: {validation_result}"),
            )
        }
    };

    Some(TransactionInputValidationSummary {
        spending_txid,
        previous_txid,
        input_index: input_index as u64,
        previous_vout: previous_vout as u64,
        previous_output_value,
        is_valid,
        validation_result,
        message,
    })
}

#[uniffi::export]
pub fn local_node_summary(network: String) -> Option<LocalNodeSummary> {
    let chain_type = parse_chain_type(&network)?;
    let runtime = ensure_local_node_runtime(chain_type)?;
    let (data_dir, blocks_dir) = local_node_paths(chain_type);

    Some(LocalNodeSummary {
        network: network.trim().to_ascii_lowercase(),
        chain_type: format!("{chain_type:?}"),
        data_dir: data_dir.display().to_string(),
        blocks_dir: blocks_dir.display().to_string(),
        is_ready: Arc::strong_count(&runtime) > 0,
        message: format!("Local Rust node ready for {chain_type:?}."),
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

fn ensure_local_node_runtime(chain_type: ChainType) -> Option<Arc<LocalNodeRuntime>> {
    let key = format!("{chain_type:?}");
    let cache = LOCAL_NODE_CACHE.get_or_init(|| Mutex::new(HashMap::new()));

    if let Some(runtime) = cache.lock().ok()?.get(&key).cloned() {
        return Some(runtime);
    }

    let (data_dir, blocks_dir) = local_node_paths(chain_type);
    fs::create_dir_all(&data_dir).ok()?;
    fs::create_dir_all(&blocks_dir).ok()?;

    let context = ContextBuilder::new().chain_type(chain_type).build().ok()?;
    let chainman = ChainstateManager::builder(
        &context,
        data_dir.to_str()?,
        blocks_dir.to_str()?,
    )
    .ok()?
    .block_tree_db_in_memory(true)
    .chainstate_db_in_memory(matches!(chain_type, ChainType::Regtest))
    .build()
    .ok()?;

    let runtime = Arc::new(LocalNodeRuntime {
        _context: context,
        _chainman: chainman,
    });

    cache.lock().ok()?.insert(key, Arc::clone(&runtime));
    Some(runtime)
}

fn local_node_paths(chain_type: ChainType) -> (PathBuf, PathBuf) {
    let mut root = env::temp_dir();
    root.push("rust-bitcoinkernel-xcode");
    root.push(match chain_type {
        ChainType::Mainnet => "mainnet",
        ChainType::Testnet => "testnet",
        ChainType::Testnet4 => "testnet4",
        ChainType::Signet => "signet",
        ChainType::Regtest => "regtest",
    });

    let data_dir = root.join("data");
    let blocks_dir = root.join("blocks");
    (data_dir, blocks_dir)
}
