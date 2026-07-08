    use bitcoinkernel::{
        prelude::*, Block, BLOCK_CHECK_ALL, BlockHash, BlockHeader, BlockTreeEntry, Chain,
        ChainType, Context, ContextBuilder, KernelError, Log, LogLevel, Logger,
        NotificationCallbackRegistry, ProcessBlockResult, Transaction, TxOut, VERIFY_ALL,
    };

    fn assert_type<T>() {}

    fn re_exports_core_state_and_logging_types() {
        assert_type::<Block>();
        assert_type::<BlockHash>();
        assert_type::<BlockHeader>();
        assert_type::<BlockTreeEntry>();
        assert_type::<Chain>();
        assert_type::<ChainType>();
        assert_type::<Context>();
        assert_type::<ContextBuilder>();
        assert_type::<KernelError>();
        assert_type::<Logger>();
        assert_type::<LogLevel>();
        assert_type::<NotificationCallbackRegistry>();
        assert_type::<ProcessBlockResult>();
        assert_type::<Transaction>();
        assert_type::<TxOut>();
    }

    fn re_exports_flags_and_prelude_traits() {
        let _ = VERIFY_ALL;
        let _ = BLOCK_CHECK_ALL;

        struct TestLog;

        impl Log for TestLog {
            fn log(&self, _message: &str) {}
        }

        fn assert_log_trait<T: Log>() {}
        fn assert_script_pubkey_ext<T: ScriptPubkeyExt>() {}
        fn assert_transaction_ext<T: TransactionExt>() {}
        fn assert_tx_out_ext<T: TxOutExt>() {}

        assert_log_trait::<TestLog>();
        assert_script_pubkey_ext::<bitcoinkernel::ScriptPubkey>();
        assert_transaction_ext::<Transaction>();
        assert_tx_out_ext::<TxOut>();
    }

fn main(){

	re_exports_core_state_and_logging_types();
	re_exports_flags_and_prelude_traits();
}
