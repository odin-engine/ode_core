/*
    2025 (c) Oleh, https://github.com/zm69
*/

package ode_core__tests

// Base
    import "base:runtime"

// Core
    import "core:testing"
    import "core:fmt"
    import "core:log"
    import "core:slice"
    import "core:mem"
    import "core:time"

// ode_core
    import oc ".."

///////////////////////////////////////////////////////////////////////////////
// Tests

    @(test)
    ix_gen_factory__test :: proc(t: ^testing.T) {

        // Log into console when panic happens
        context.logger = log.create_console_logger()
        defer log.destroy_console_logger(context.logger)

        allocator := context.allocator
        context.allocator = mem.panic_allocator() // to make sure no allocations happen outside provided allocator

        id_1: oc.ix_gen 
        id_2: oc.ix_gen
        id_3: oc.ix_gen

        testing.expect(t, id_1 == id_2)

        id_1.ix = oc.DELETED_INDEX
        id_2.ix = oc.DELETED_INDEX

        testing.expect(t, id_1 == id_2)
        testing.expect(t, id_1.ix == oc.DELETED_INDEX)
        testing.expect(t, id_1.gen == 0)

        id_1.gen = 255
        testing.expect(t, id_1.ix == oc.DELETED_INDEX)
        testing.expect(t, id_1 != id_2)

        factory: oc.Ix_Gen_Factory

        defer oc.ix_gen_factory__terminate(&factory, allocator)
        oc.ix_gen_factory__init(&factory, 2, allocator)

        testing.expect(t, factory.cap == 2)
        testing.expect(t, factory.freed_count == 0)
        testing.expect(t, factory.created_count == 0)

        err: oc.Core_Error

        id_1, err = oc.ix_gen_factory__new_id(&factory)
        testing.expect(t, err == oc.Core_Error.None)
        testing.expect(t, id_1.ix == 0)
        testing.expect(t, id_1.gen == 0)

        id_2, err = oc.ix_gen_factory__new_id(&factory)
        testing.expect(t, err == oc.Core_Error.None)
        testing.expect(t, id_2.ix == 1)
        testing.expect(t, id_2.gen == 0)

        id_3, err = oc.ix_gen_factory__new_id(&factory)
        testing.expect(t, err == oc.Core_Error.Container_Is_Full)
        testing.expect(t, id_3.ix == oc.DELETED_INDEX)
        testing.expect(t, id_3.gen == 0)

        testing.expect(t, id_1.ix == 0)
        err = oc.ix_gen_factory__free_id(&factory, id_1)
        testing.expect(t, err == oc.Core_Error.None)
        testing.expect(t, factory.created_count == 2)
        testing.expect(t, factory.freed_count == 1)

        id_1, err = oc.ix_gen_factory__new_id(&factory)
        testing.expect(t, err == oc.Core_Error.None)
        testing.expect(t, id_1.ix == 0)
        testing.expect(t, id_1.gen == 1)
        
        err = oc.ix_gen_factory__free_id(&factory, id_1)
        testing.expect(t, err == oc.Core_Error.None)
        testing.expect(t, factory.created_count == 2)
        testing.expect(t, factory.freed_count == 1)

        id_1, err = oc.ix_gen_factory__new_id(&factory)
        testing.expect(t, err == oc.Core_Error.None)
        testing.expect(t, id_1.ix == 0)
        testing.expect(t, id_1.gen == 2)

        err = oc.ix_gen_factory__free_id(&factory, id_1)
        testing.expect(t, err == oc.Core_Error.None)
        testing.expect(t, factory.created_count == 2)
        testing.expect(t, factory.freed_count == 1)
        testing.expect(t, oc.ix_gen_factory__is_freed(&factory, id_1))
        testing.expect(t, oc.ix_gen_factory__is_freed(&factory, id_2) == false)

        err = oc.ix_gen_factory__free_id(&factory, id_2)
        testing.expect(t, err == oc.Core_Error.None)
        testing.expect(t, factory.created_count == 2)
        testing.expect(t, factory.freed_count == 2)
        testing.expect(t, oc.ix_gen_factory__is_freed(&factory, id_1))
        testing.expect(t, oc.ix_gen_factory__is_freed(&factory, id_2))

        id_4, id_5: oc.ix_gen

        testing.expect(t, id_1 != factory.items[0])
        testing.expect(t, factory.items[0].ix == oc.DELETED_INDEX)
        testing.expect(t, factory.items[0].gen == 2)
        testing.expect(t, id_2 != factory.items[1])
        testing.expect(t, factory.items[1].ix == oc.DELETED_INDEX)
        testing.expect(t, factory.items[1].gen == 0)

        id_3, err = oc.ix_gen_factory__new_id(&factory)
        testing.expect(t, err == oc.Core_Error.None)
        testing.expect(t, id_3.ix == 1)
        testing.expect(t, id_3.gen == 1)
        testing.expect(t, factory.created_count == 2)
        testing.expect(t, factory.freed_count == 1)
        testing.expect(t, oc.ix_gen_factory__is_freed(&factory, id_3) == false)
        testing.expect(t, oc.ix_gen_factory__is_freed(&factory, id_2) == false)

        id_4, err = oc.ix_gen_factory__new_id(&factory)
        testing.expect(t, err == oc.Core_Error.None)
        testing.expect(t, id_4.ix == 0)
        testing.expect(t, id_4.gen == 3)
        testing.expect(t, factory.created_count == 2)
        testing.expect(t, factory.freed_count == 0)

        testing.expect(t, id_4 != id_1)
        testing.expect(t, id_3 != id_2)

        id_5, err = oc.ix_gen_factory__new_id(&factory)
        testing.expect(t, err == oc.Core_Error.Container_Is_Full)
        testing.expect(t, factory.created_count == 2)
        testing.expect(t, factory.freed_count == 0)
    }

    @(test)
    sparse_arr__test :: proc(t: ^testing.T) {
        // Log into console when panic happens
        context.logger = log.create_console_logger()
        defer log.destroy_console_logger(context.logger)

        allocator := context.allocator
        context.allocator = mem.panic_allocator() // to make sure no allocations happen outside provided allocator

        ua_1: oc.Sparce_Arr(int)
        a : int = 66
        b : int = 99
        c : int = 88

        alloc_err: runtime.Allocator_Error
        err: oc.Core_Error
        ix: int

        defer oc.sparse_arr__terminate(&ua_1, allocator)
        alloc_err = oc.sparse_arr__init(&ua_1, 2, allocator)
        testing.expect(t, alloc_err == runtime.Allocator_Error.None)

        testing.expect(t, ua_1.has_nil_item == false)
        testing.expect(t, oc.sparse_arr__len(&ua_1) == 0) 
        testing.expect(t, ua_1.cap == 2)

        ix, err = oc.sparse_arr__add(&ua_1, &a)
        testing.expect(t, ix == 0)
        testing.expect(t, err == oc.Core_Error.None)

        ix, err = oc.sparse_arr__add(&ua_1, &b)
        testing.expect(t, ix == 1)
        testing.expect(t, err == oc.Core_Error.None)

        ix, err = oc.sparse_arr__add(&ua_1, &c)
        testing.expect(t, ix == oc.DELETED_INDEX)
        testing.expect(t, err == oc.Core_Error.Container_Is_Full)
        testing.expect(t, ua_1.has_nil_item == false)
        testing.expect(t, oc.sparse_arr__len(&ua_1) == 2)

        // oc.sparse_arr__remove_by_index(&ua_1, 999)
        //testing.expect(t, err == oc.Core_Error.Out_Of_Bounds)

        oc.sparse_arr__remove_by_index(&ua_1, 0)

        testing.expect(t, ua_1.has_nil_item == true)
        testing.expect(t, oc.sparse_arr__len(&ua_1) == 2)
        testing.expect(t, ua_1.items[0] == nil)

        err = oc.sparse_arr__remove_by_value(&ua_1, &b)
        testing.expect(t, err == oc.Core_Error.None)
        testing.expect(t, ua_1.has_nil_item == true)
        testing.expect(t, oc.sparse_arr__len(&ua_1) == 1)

        #no_bounds_check {
            testing.expect(t, ua_1.items[1] == nil)
            testing.expect(t, ua_1.items[0] == nil)
        }

        err = oc.sparse_arr__remove_by_value(&ua_1, &c)
        testing.expect(t, err == oc.Core_Error.Not_Found)
        testing.expect(t, ua_1.has_nil_item == true)
        testing.expect(t, oc.sparse_arr__len(&ua_1) == 1)

        #no_bounds_check {
            testing.expect(t, ua_1.items[1] == nil)
            testing.expect(t, ua_1.items[0] == nil)
        }

        ix, err = oc.sparse_arr__add(&ua_1, &a)
        testing.expect(t, ix == 0)
        testing.expect(t, err == oc.Core_Error.None)

        ix, err = oc.sparse_arr__add(&ua_1, &b)
        testing.expect(t, ix == 1)
        testing.expect(t, err == oc.Core_Error.None)
        testing.expect(t, oc.sparse_arr__len(&ua_1) == 2)
        testing.expect(t, ua_1.has_nil_item == false)

        // removing tail item, so it should just decrease ua_1.count
        oc.sparse_arr__remove_by_index(&ua_1, 1)
        testing.expect(t, oc.sparse_arr__len(&ua_1) == 1)
        testing.expect(t, ua_1.has_nil_item == false)

    }

    @(test)
    dense_arr__test :: proc(t: ^testing.T) {
        // Log into console when panic happens
        context.logger = log.create_console_logger()
        defer log.destroy_console_logger(context.logger)

        allocator := context.allocator
        context.allocator = mem.panic_allocator() // to make sure no allocations happen outside provided allocator

        arr: oc.Dense_Arr(int)

        a : int = 66
        b : int = 99
        c : int = 88

        alloc_err: runtime.Allocator_Error
        err: oc.Core_Error
        ix: int

        defer oc.dense_arr__terminate(&arr, allocator)
        alloc_err = oc.dense_arr__init(&arr, 2, allocator)
        testing.expect(t, alloc_err == runtime.Allocator_Error.None)

        ix, err = oc.dense_arr__add(&arr, a)
        testing.expect(t, ix == 0)
        testing.expect(t, err == oc.Core_Error.None)

        ix, err = oc.dense_arr__add(&arr, b)
        testing.expect(t, ix == 1)
        testing.expect(t, err == oc.Core_Error.None)
        testing.expect(t, oc.dense_arr__len(&arr) == 2)
        testing.expect(t, arr.items[0] == 66)
        testing.expect(t, arr.items[1] == 99)

        ix, err = oc.dense_arr__add(&arr, c)
        testing.expect(t, ix == oc.DELETED_INDEX)
        testing.expect(t, err == oc.Core_Error.Container_Is_Full)
        testing.expect(t, oc.dense_arr__len(&arr) == 2)

        // oc.dense_arr__remove_by_index(arr, 999)
        //testing.expect(t, err == oc.Core_Error.Out_Of_Bounds)

        oc.dense_arr__remove_by_index(&arr, 0)

        testing.expect(t, oc.dense_arr__len(&arr) == 1)
        testing.expect(t, arr.items[0] == 99)

        err = oc.dense_arr__remove_by_value(&arr, b)
        testing.expect(t, err == oc.Core_Error.None)
        testing.expect(t, oc.dense_arr__len(&arr) == 0)

        err = oc.dense_arr__remove_by_value(&arr, c)
        testing.expect(t, err == oc.Core_Error.Not_Found)

        ix, err = oc.dense_arr__add(&arr, a)
        testing.expect(t, ix == 0)
        testing.expect(t, err == oc.Core_Error.None)

        ix, err = oc.dense_arr__add(&arr, b)
        testing.expect(t, ix == 1)
        testing.expect(t, err == oc.Core_Error.None)
        testing.expect(t, oc.dense_arr__len(&arr) == 2)

        oc.dense_arr__remove_by_index(&arr, 1)
        testing.expect(t, oc.dense_arr__len(&arr) == 1)
        testing.expect(t, arr.items[0] == 66)
    }