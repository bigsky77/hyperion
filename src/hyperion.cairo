### ==================================
###              HYPERION
### ==================================

%lang starknet

### ========== dependencies ==========

# starkware-std
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero

# openzeppelin
from src.openzeppelin.token.erc20.IERC20 import IERC20

### =========== constants ============

const PRECISION = 18 ** 10
const TOKEN_A = 1
const TOKEN_B = 2

### ======= storage variables ========

@storage_var
func token_index_to_addr(token_index : felt) -> (token_address : felt):
end

@storage_var
func fee() -> (fee : felt):
end

@storage_var
func admin_fee() -> (admin_fee : felt):
end

### ========== constructor ===========

@constructor
func constructor{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(
        token_a_address : felt,
        token_b_address : felt,
        factory : felt,
        _A : felt,
        _fee : felt,
        _admin_fee : felt,
):
    with_attr error_message("Token cannot be from the zero address"):
        tempvar x = token_a_address * token_b_address
        assert_not_zero(x)
    end

    token_index_to_addr.write(token_index=TOKEN_A, value=token_a_address)
    token_index_to_addr.write(token_index=TOKEN_B, value=token_b_address)
    
    fee.write(_fee)
    admin_fee.write(_admin_fee)

    return()
end
