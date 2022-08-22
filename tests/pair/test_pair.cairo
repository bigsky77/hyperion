### ==================================
###          HYPERION TESTS
### ==================================

%lang starknet

### ========== dependencies ==========

# starkware-std
from starkware.cairo.common.cairo_builtins import HashBuiltin

# openzeppelin
from src.openzeppelin.token.erc20.IERC20 import IERC20
from src.openzeppelin.token.erc20.library import ERC20

from src.interfaces.IHyperion import IHyperion

### =========== constants ============

const USER = 'user'
const TOKEN_NAME_A = 'ajax'
const TOKEN_NAME_B = 'shryke'
const SYMBOL_A = 'AJX'
const SYMBOL_B = 'SHRK'
const DECIMALS = 18
const SUPPLY_HI = 100000
const SUPPLY_LO = 0
const ARR_LEN = 2

### ============= setup ==============

@external
func __setup__{syscall_ptr : felt*}():
    alloc_locals
    
    tempvar token_a
    tempvar token_b
    tempvar hyperion    
    %{
        ids.token_a = deploy_contract(
            "./lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20.cairo", 
            [ids.TOKEN_NAME_A, ids.SYMBOL_A, ids.DECIMALS, ids.SUPPLY_LO, ids.SUPPLY_HI, ids.USER]).contract_address
        context.token_a = ids.token_a

        ids.token_b = deploy_contract(
            "./lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20.cairo", 
            [ids.TOKEN_NAME_B, ids.SYMBOL_B, ids.DECIMALS, ids.SUPPLY_LO, ids.SUPPLY_HI, ids.USER]).contract_address
        context.token_b = ids.token_b
        
        ids.hyperion = deploy_contract(
            "./src/hyperion.cairo",
            [ids.ARR_LEN, ids.token_a, ids.token_b, 100]).contract_address
        context.hyperion = ids.hyperion
    %}

    return()
end

@external
func test_get_token{
        syscall_ptr : felt*,
        #pedersen_ptr : HashBuiltin*,
        range_check_ptr,
}():
    alloc_locals

    let (hyperion) = hyperion_instance.deployed()
    let (token_a) = token_a_instance.deployed()
    let (token_b) = token_b_instance.deployed()
    
    let (address_b) = IHyperion.get_token(hyperion, token_index=2)
    assert token_b = address_b

    let (address_a) = IHyperion.get_token(hyperion, token_index=1)
    assert token_a = address_a

    return()
end

@external
func test_exchange{
        syscall_ptr : felt*,
        #pedersen_ptr : HashBuiltin*,
        range_check_ptr,
}():
    alloc_locals

    let (hyperion) = hyperion_instance.deployed()
    let (token_a) = token_a_instance.deployed()
    let (token_b) = token_b_instance.deployed()
    
    let (res) = IHyperion.exchange(hyperion, 1, 2, 100)
    assert res = 1100
    return()
end

### ======== token-contracts =========

namespace hyperion_instance:
    func deployed() -> (contract : felt):
        tempvar hyperion
        %{ ids.hyperion = context.hyperion %}
        return (contract=hyperion)
    end
            
end

namespace token_a_instance:
    func deployed() -> (token_contract : felt):
        tempvar token_a
        %{ ids.token_a = context.token_a %}
        return (token_contract=token_a)
    end
            
end

namespace token_b_instance:
    func deployed() -> (token_contract : felt):
        tempvar token_b
        %{ ids.token_b = context.token_b %}
        return (token_contract=token_b)
    end
end

