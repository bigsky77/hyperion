### ==================================
###          HYPERION FACTORY
### ==================================

%lang starknet

### ========== dependencies ==========

# starkware cairo-std
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero, assert_lt
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import deploy

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
}(class_hash : felt):

# prevents first salt from being 0 
    salt.write(1)
    hyperion_class_hash.write(class_hash) 

    return()
end

### ====== external functions ========

# this is a hack - only creates a two token pool initially
@external
func create_pool{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
}(tokens_len : felt, tokens : felt*) -> (pool_address : felt):
    alloc_locals

    let (local hash) = hyperion_class_hash.read()

    let (current_salt) = salt.read()
    salt.write(current_salt + 1)
       
    # ensure no zero addresses 
    not_zero_address(tokens_len, tokens)
    
    let (calldata) = alloc()
    assert [calldata] = tokens_len
    assert [calldata + 1] = tokens[0]
    assert [calldata + 2] = tokens[1]
    
    let (pool_address) = deploy(
        class_hash=hash,
        contract_address_salt=current_salt,
        constructor_calldata_size=3,
        constructor_calldata=calldata
    )
    
    # pool index trails salt by 1
    pool.write(current_salt, pool_address)
    
    return(pool_address)
end

### ============= utils ==============

@external
func not_zero_address{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(arr_len : felt, arr : felt*) -> (res : felt):
    alloc_locals

    if arr_len == 0:
        return(0)
    end

    let address = arr[arr_len - 1]
    assert_not_zero(address)    
    
    let (res) = not_zero_address(arr_len - 1, arr)
    return(res)
end









