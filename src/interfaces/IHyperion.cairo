### ==================================
###          HYPERION INTERFACE
### ==================================

%lang starknet

### ========== dependencies ==========

@contract_interface
namespace IHyperion: 
 
    func get_token(token_index : felt) -> (token_address : felt):
    end

    func exchange(i : felt, j : felt, _dx : felt) -> (pool_balance : felt, i_balance : felt, j_balance : felt, dy : felt):
    end

    func view_D() -> (res : felt):
    end

    func view_A() -> (res : felt):
    end

end








