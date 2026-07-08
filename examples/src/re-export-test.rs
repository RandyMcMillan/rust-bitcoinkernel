fn re_exports_bitcoinkernel_items() {
    use bitcoinkernel::{Block, ChainType, ContextBuilder, KernelError, VERIFY_ALL};

    let _ = VERIFY_ALL;

    fn assert_type<T>() {}

    assert_type::<Block>();
    assert_type::<ChainType>();
    assert_type::<ContextBuilder>();
    assert_type::<KernelError>();
}
fn main(){
    re_exports_bitcoinkernel_items();

}
