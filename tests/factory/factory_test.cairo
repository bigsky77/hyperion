### ==================================
###          FACTORY TESTS
### ==================================

%lang starknet
%builtins range_check

### ========== dependencies ==========

# starkware-std
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc

# openzeppelin
from src.openzeppelin.token.erc20.IERC20 import IERC20
from openzeppelin.token.erc20.library import ERC20

from src.interfaces.IFactory import IFactory

### =========== constants ============

const USER = 'user'
const TOKEN_NAME_A = 'ajax'
const TOKEN_NAME_B = 'shryke'
const SYMBOL_A = 'AJX'
const SYMBOL_B = 'SHRK'
const DECIMALS = 18
const SUPPLY_HI = 100000
const SUPPLY_LO = 0

## ============= setup ==============

@external
func __setup__{syscall_ptr : felt*}():
    alloc_locals
    
    tempvar token_a
    tempvar token_b
    tempvar hyperion_class_hash
    tempvar factory
    tempvar hyperion
    %{
        ids.hyperion_class_hash = declare("./src/hyperion.cairo").class_hash
        context.hyperion_class_hash = ids.hyperion_class_hash

        ids.token_a = deploy_contract(
            "./lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20.cairo", 
            [ids.TOKEN_NAME_A, ids.SYMBOL_A, ids.DECIMALS, ids.SUPPLY_LO, ids.SUPPLY_HI, ids.USER]).contract_address
        context.token_a = ids.token_a

        ids.token_b = deploy_contract(
            "./lib/cairo_contracts/src/openzeppelin/token/erc20/presets/ERC20.cairo", 
            [ids.TOKEN_NAME_B, ids.SYMBOL_B, ids.DECIMALS, ids.SUPPLY_LO, ids.SUPPLY_HI, ids.USER]).contract_address
        context.token_b = ids.token_b

        ids.factory = deploy_contract(
            "./src/factory.cairo",
            [ids.hyperion_class_hash]).contract_address
        context.factory = ids.factory

        ids.hyperion = deploy_contract(
            "./src/hyperion.cairo",
            [2, ids.token_a, ids.token_b]).contract_address
        context.hyperion = ids.hyperion
        
    %}

    return()
end

### ======== token-contracts =========

@external
func test_create_pool{
        syscall_ptr : felt*,
        #pedersen_ptr : HashBuiltin*,
        range_check_ptr,
}():
    alloc_locals

    let (factory) = factory_instance.deployed()
    let (token_a) = token_a_instance.deployed()
    let (token_b) = token_b_instance.deployed()
    
    let (tokens : felt*) = alloc()
    assert [tokens] = token_a
    assert [tokens + 1] = token_b
    
    IFactory.create_pool(factory, 2, tokens)

    return()
end

### ======= contract-instances ======= 

namespace factory_instance:
    func deployed() -> (factory_instance : felt):
        tempvar factory
        %{
            ids.factory = context.factory
        %}
        return(factory_instance=factory)
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



    








