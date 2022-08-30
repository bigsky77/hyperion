### ==================================
###          HYPERION INTERFACE
### ==================================

%lang starknet

### ========== dependencies ==========

from starkware.cairo.common.uint256 import Uint256, uint256_check, uint256_eq, uint256_not

### ============= tests ==============

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

    func mint(tokens_len : felt, tokens : felt*) -> (res : Uint256):
    end

    func burn(_burn_amount : felt) -> (res : Uint256):
    end

end








