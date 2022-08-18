### ==================================
###              HYPERION
### ==================================

%lang starknet
%builtins pedersen range_check 

### ========== dependencies ==========

# starkware cairo-std
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_not_zero, assert_lt
from starkware.cairo.common.math_cmp import is_le 
from starkware.cairo.common.uint256 import Uint256

# starkware starknet-std
from starkware.starknet.common.syscalls import get_block_timestamp

# openzeppelin
from src.openzeppelin.token.erc20.IERC20 import IERC20

### =========== constants ============

### ======= storage variables ========

@storage_var
func n_tokens() -> (value : felt):
end

### ========== constructor ===========

@constructor
func constructor{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(tokens_len : felt, tokens : felt*):
    alloc_locals

    n_tokens.write(value=tokens_len)

    return()
end


### ======== view-functions ==========


 
