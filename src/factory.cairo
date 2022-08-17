### ==================================
###          HYPERION FACTORY
### ==================================

%lang starknet

### ========== dependencies ==========

# starkware cairo-std
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero, assert_lt
from starkware.cairo.common.alloc import alloc

### ======= storage variables ========

@storage_var
func salt() -> (value : felt):
end

@storage_var
func pool(pool_index : felt) -> (pool_address : felt):
end

@storage_var
func hyperion_class_hash() -> (class_hash : felt):
end

### ========== constructor ===========

@constructor
func constructor{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(hyperion_class_hash : felt):

# prevents first salt from 
    salt.write(1)
    hyperion_class_hash.write(hyperion_class_hash) 

    return()
end

### ====== external functions ========

@external
func create_pool{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
}(tokens_len : felt, tokens : felt*) -> (pool_address : felt):

    let (class_hash) = hyperion_class_hash.read()
    
    let (current_salt) = salt.read()
    salt.write(current_salt + 1)

   # ensure no zero addresses 
    not_zero_address(tokens_len, tokens)

    let (pool_address) = deploy(
        class_hash=class_hash,
        contract_address_salt=current_salt,
        constructor_calldata_size=tokens_len,
        constructor_calldata=tokens,
    )
    
    return()
end

### ============= utils ==============

func not_zero_address{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(arr_lens : felt, arr : felt*) -> (res : felt):
    if arr_lens == 0:
        return(0)
    end

    let (local address) = arr[arr_lens]
    assert_not_zero(address)    
    
    let (res) = not_zero_address(arr_lens - 1, arr)
    return(res)
end





