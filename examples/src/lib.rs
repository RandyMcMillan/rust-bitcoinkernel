pub use bitcoinkernel::*;

#[cfg(test)]
mod tests {
    use super::*;
    use super::prelude::{ScriptPubkeyExt, TransactionExt, TxOutExt};
    use std::error::Error;

    struct TestLog;

    impl Log for TestLog {
        fn log(&self, _: &str) {}
    }

    #[test]
    fn public_reexports_are_usable() {
        fn assert_log<T: Log>() {}
        fn assert_script_pubkey_ext<T: ScriptPubkeyExt>() {}
        fn assert_transaction_ext<T: TransactionExt>() {}
        fn assert_tx_out_ext<T: TxOutExt>() {}

        assert_log::<TestLog>();
        assert_script_pubkey_ext::<ScriptPubkey>();
        assert_transaction_ext::<Transaction>();
        assert_tx_out_ext::<TxOut>();

        let _ = VERIFY_ALL;
        let _ = BLOCK_CHECK_ALL;
        let _ = std::mem::size_of::<Block>();
        let _ = std::mem::size_of::<ChainType>();
        let _ = std::mem::size_of::<Context>();
    }

    #[test]
    fn kernel_error_formats_and_exposes_sources() {
        let invalid_length = KernelError::InvalidLength {
            expected: 2,
            actual: 5,
        };
        assert_eq!(invalid_length.to_string(), "Invalid length: expected 2, got 5");

        let script_verify = KernelError::ScriptVerify(ScriptVerifyError::Invalid);
        assert_eq!(
            script_verify.source().map(ToString::to_string),
            Some("Script verification failed".to_string())
        );
    }
}
