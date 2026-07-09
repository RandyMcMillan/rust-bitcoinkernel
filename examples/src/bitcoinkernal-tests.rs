use std::any::{type_name, type_name_of_val};

use bitcoinkernel::{
    prelude::*, Block, BlockHash, BlockHeader, BlockTreeEntry, Chain, ChainType, Context,
    ContextBuilder, KernelError, Log, LogLevel, Logger, NotificationCallbackRegistry,
    ProcessBlockResult, Transaction, TxOut, BLOCK_CHECK_ALL, VERIFY_ALL,
};

fn print_type<T>(label: &str) {
    println!("{label}: {}", type_name::<T>());
}

fn re_exports_core_state_and_logging_types() {
    println!("core/state/logging re-export checks");
    print_type::<Block>("Block");
    print_type::<BlockHash>("BlockHash");
    print_type::<BlockHeader>("BlockHeader");
    print_type::<BlockTreeEntry>("BlockTreeEntry");
    print_type::<Chain>("Chain");
    print_type::<ChainType>("ChainType");
    print_type::<Context>("Context");
    print_type::<ContextBuilder>("ContextBuilder");
    print_type::<KernelError>("KernelError");
    print_type::<Logger>("Logger");
    print_type::<LogLevel>("LogLevel");
    print_type::<NotificationCallbackRegistry>("NotificationCallbackRegistry");
    print_type::<ProcessBlockResult>("ProcessBlockResult");
    print_type::<Transaction>("Transaction");
    print_type::<TxOut>("TxOut");
}

fn re_exports_flags_and_prelude_traits() {
    println!("flags and prelude re-export checks");
    println!("VERIFY_ALL: {}", type_name_of_val(&VERIFY_ALL));
    println!("BLOCK_CHECK_ALL: {}", type_name_of_val(&BLOCK_CHECK_ALL));

    struct TestLog;

    impl Log for TestLog {
        fn log(&self, message: &str) {
            println!("TestLog: {message}");
        }
    }

    fn print_log_trait<T: Log>() {
        println!("Log trait available for {}", type_name::<T>());
    }

    fn print_script_pubkey_ext<T: ScriptPubkeyExt>() {
        println!("ScriptPubkeyExt available for {}", type_name::<T>());
    }

    fn print_transaction_ext<T: TransactionExt>() {
        println!("TransactionExt available for {}", type_name::<T>());
    }

    fn print_tx_out_ext<T: TxOutExt>() {
        println!("TxOutExt available for {}", type_name::<T>());
    }

    print_log_trait::<TestLog>();
    print_script_pubkey_ext::<bitcoinkernel::ScriptPubkey>();
    print_transaction_ext::<Transaction>();
    print_tx_out_ext::<TxOut>();
}

fn main() {
    println!("re-export binary starting");
    re_exports_core_state_and_logging_types();
    re_exports_flags_and_prelude_traits();
    println!("re-export binary finished");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn binary_reexports_are_usable() {
        fn assert_log<T: Log>() {}
        fn assert_script_pubkey_ext<T: ScriptPubkeyExt>() {}
        fn assert_transaction_ext<T: TransactionExt>() {}
        fn assert_tx_out_ext<T: TxOutExt>() {}

        struct TestLog;

        impl Log for TestLog {
            fn log(&self, _: &str) {}
        }

        assert_log::<TestLog>();
        assert_script_pubkey_ext::<bitcoinkernel::ScriptPubkey>();
        assert_transaction_ext::<Transaction>();
        assert_tx_out_ext::<TxOut>();

        let _ = VERIFY_ALL;
        let _ = BLOCK_CHECK_ALL;
    }
}
