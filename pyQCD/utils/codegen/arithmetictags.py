"""This module contains template tags for generating arithmetic operations
for the specified Cython types."""

from .typedefs import ArrayDef, LatticeDef, TypeDef


def filter_types(typedef, matrix_shape, is_array, is_lattice):
    """Determine whether supplied typedef fits the specified requirements"""
    correct_shape = typedef.matrix_shape == matrix_shape
    is_array_correct = isinstance(typedef, ArrayDef) == is_array
    is_lattice_correct = isinstance(typedef, LatticeDef) == is_lattice
    return correct_shape and is_array_correct and is_lattice_correct


def generate_scalar_operations(typedef, scalar_typedefs):
    """Generate a list of tuples specifying and operand types.

    Args:
      typedef (ContainerDef): A ContainerDef instance specifying the type to
        generate operations for.
      scalar_typedefs (iterable): An iterable of TypeDef instances to compare
        the supplied typedef variable against.

    Returns:
      list: list of tuples specifying the operation.
    """
    operations = []
    for scalar_typedef in scalar_typedefs:
        for op in "*/+-":
            operations.append((op, typedef, typedef, scalar_typedef, None))

    return operations


def generate_matrix_operations(lhs, rhss):
    """Generate a list of tuples specifying operations and operand types.

    Args:
      typedef (ContainerDef): A ContainerDef instance specifying the type to
        generate operations for.
      other_typedefs (iterable): An iterable of ContainerDef instances to
        compare the supplied typedef variable against.

    Returns:
      list: list of tuples specifying the operation
    """
    operations = []
    lhs_is_lattice = isinstance(lhs, LatticeDef)
    lhs_is_array = isinstance(lhs, ArrayDef)

    for rhs in rhss:
        rhs_is_lattice = isinstance(rhs, LatticeDef)
        rhs_is_array = isinstance(rhs, ArrayDef)
        result_is_lattice = lhs_is_lattice or rhs_is_lattice
        result_is_array = lhs_is_array or rhs_is_array
        try:
            result_shape = lhs.matrix_shape[0], rhs.matrix_shape[1]
        except IndexError:
            result_shape = lhs.matrix_shape[0],
        filter_args = result_shape, result_is_array, result_is_lattice
        try:
            result_typedef = [e for e in rhss
                              if filter_types(e, *filter_args)][0]
        except IndexError:
            continue
        can_multiply = lhs.matrix_shape[-1] == rhs.matrix_shape[0]
        can_addsub = lhs.matrix_shape == rhs.matrix_shape

        need_broadcast = (lhs_is_lattice != rhs_is_lattice and
                          lhs_is_array != rhs_is_array)
        if need_broadcast:
            broadcast = "R" if lhs_is_lattice else "L"
        else:
            broadcast = None

        if can_multiply:
            operations.append(("*", result_typedef, lhs, rhs, broadcast))
        if can_addsub:
            for op in "+-":
                operations.append((op, result_typedef, lhs, rhs, broadcast))

    return operations


def arithmetic_code(typedef, typedefs, precision):
    """Generate code for constructors and destructors.

    Args:
      typedef (ContainerDef): A ContainerDef instance specifying the type to
        generate code for.
      typedefs (iterable): An iterable of ContainerDef instances to compare
        the specified typedef to and .
    """
    scalar_typedefs = [TypeDef("int", "int", "", True),
                       TypeDef(precision, precision, "", True),
                       TypeDef("Complex", "Complex", "complex", True)]
    operations = generate_scalar_operations(typedef, scalar_typedefs)
    operations.extend(generate_matrix_operations(typedef, typedefs))

    from . import env
    template = env.get_template("core/arithmetic.pyx")
    return template.render(typedef=typedef, operations=operations)