"""
Do NOT edit this file. It was generated automatically from a template.

Please edit the files within the template directory of the pyQCD package tree
and run "python setup.py codegen" in the root of the source tree.
"""

from cpython cimport Py_buffer
from libcpp.vector cimport vector

import numpy as np

cimport atomics
cimport core
from core cimport _ColourMatrix, ColourMatrix, _LatticeColourMatrix, LatticeColourMatrix, _ColourVector, ColourVector, _LatticeColourVector, LatticeColourVector
cdef class Layout:

    def __init__(self, *args, **kwargs):
        raise NotImplementedError("This class is pure-virtual. Please use a "
                                  "layout class that inherits from it.")

    property shape:
        def __get__(self):
            """The layout shape"""
            return self.instance.shape()

    property ndims:
        def __get__(self):
            """The number of dimensions in the layout"""
            return self.instance.num_dims()

cdef class LexicoLayout(Layout):

    def __cinit__(self, shape):
        self.instance = new core._LexicoLayout(shape)

    def __deallocate__(self):
        del self.instance

    def __init__(self, *args, **kwargs):
        pass

cdef class EvenOddLayout(Layout):

    def __cinit__(self, shape):
        self.instance = new core._EvenOddLayout(shape)

    def __deallocate__(self):
        del self.instance

    def __init__(self, *args, **kwargs):
        pass


cdef class ColourMatrix:
    """Statically-sized colour matrix of shape (3, 3).

    Supports indexing and attribute lookup akin to the numpy.ndarray type.

    Attributes:
      as_numpy (numpy.ndarray): A numpy array view onto the underlying buffer
        containing the lattice data.
    """

    def __cinit__(self):
        """Constructor for ColourMatrix type. See help(ColourMatrix)."""
        self.instance = new _ColourMatrix(core._ColourMatrix_zeros())
        self.view_count = 0

    def __dealloc__(self):
        del self.instance

    def __getbuffer__(self, Py_buffer* buffer, int flags):
        cdef Py_ssize_t itemsize = sizeof(atomics.Complex)

        self.buffer_shape[0] = 3
        self.buffer_strides[0] = itemsize
        self.buffer_shape[1] = 3
        self.buffer_strides[1] = itemsize * 3

        buffer.buf = <char*>self.instance

        buffer.format = "dd"
        buffer.internal = NULL
        buffer.itemsize = itemsize
        buffer.len = itemsize * 9
        buffer.ndim = 2

        buffer.obj = self
        buffer.readonly = 0
        buffer.shape = self.buffer_shape
        buffer.strides = self.buffer_strides
        buffer.suboffsets = NULL

        self.view_count += 1

    def __releasebuffer__(self, Py_buffer* buffer):
        self.view_count -= 1

    def __getitem__(self, index):
        return self.as_numpy[index]

    def __setitem__(self, index, value):
        if hasattr(value, 'as_numpy'):
            self.as_numpy[index] = value.as_numpy
        else:
            self.as_numpy[index] = value

    def __getattr__(self, attr):
        return getattr(self.as_numpy, attr)

    property as_numpy:
        def __get__(self):
            """numpy.ndarray: A numpy array view onto the underlying data buffer
            """
            out = np.asarray(self)
            out.dtype = complex
            return out.reshape((3, 3))

        def __set__(self, value):
            out = np.asarray(self)
            out.dtype = complex
            out = out.reshape((3, 3))
            out[:] = value

    @staticmethod
    def random():
        """Generate a random SU(N) ColourMatrix instance with shape (3, 3)."""
        ret = ColourMatrix()
        ret.instance[0] = _random_colour_matrix()
        return ret

    def __repr__(self):
        return self.as_numpy.__repr__()

cdef class LatticeColourMatrix:
    """Lattice colour vector of specified shape.

    A LatticeColourMatrix instance is initialised with the specified lattice
    shape, with the specified number of colour vectors at each site.

    Supports indexing and attribute lookup akin to the numpy.ndarray type.

    Args:
      shape (tuple-like): The shape of the lattice.
      site_size (int): The number of colour vectors at each site.
    """

    def __cinit__(self, Layout layout, int site_size=1):
        """Constructor for LatticeColourMatrix type. See help(LatticeColourMatrix)."""
        self.layout = layout
        self.is_buffer_compatible = isinstance(layout, LexicoLayout)
        self.view_count = 0
        self.site_size = site_size
        self.instance = new _LatticeColourMatrix(layout.instance[0],  _ColourMatrix(_ColourMatrix_zeros()), site_size)

    def __dealloc__(self):
        del self.instance

    def __getbuffer__(self, Py_buffer* buffer, int flags):
        if not self.is_buffer_compatible:
            return

        cdef Py_ssize_t itemsize = sizeof(atomics.Complex)

        self.buffer_shape[0] = self.instance[0].volume() * self.site_size
        self.buffer_strides[0] = itemsize * 9
        self.buffer_shape[1] = 3
        self.buffer_strides[1] = itemsize
        self.buffer_shape[2] = 3
        self.buffer_strides[2] = itemsize * 3

        buffer.buf = <char*>&(self.instance[0][0])

        buffer.format = "dd"
        buffer.internal = NULL
        buffer.itemsize = itemsize
        buffer.len = itemsize * 9 * self.instance[0].volume() * self.site_size
        buffer.ndim = 3

        buffer.obj = self
        buffer.readonly = 0
        buffer.shape = self.buffer_shape
        buffer.strides = self.buffer_strides
        buffer.suboffsets = NULL

        self.view_count += 1

    def __releasebuffer__(self, Py_buffer* buffer):
        self.view_count -= 1

    def __getitem__(self, index):
        return self.as_numpy[index]

    def __setitem__(self, index, value):
        if hasattr(value, 'as_numpy'):
            self.as_numpy[index] = value.as_numpy
        else:
            self.as_numpy[index] = value

    def __getattr__(self, attr):
        return getattr(self.as_numpy, attr)

    property as_numpy:
        def __get__(self):
            """numpy.ndarray: A numpy array view onto the underlying data buffer
            """
            if not self.is_buffer_compatible:
                raise ValueError("The buffer interface is only available when "
                                 "a Lattice object uses a LexicoLayout.")
            out = np.asarray(self)
            out.dtype = complex
            return out.reshape(tuple(self.layout.instance.shape()) + (self.site_size,) + (3, 3))

        def __set__(self, value):
            if not self.is_buffer_compatible:
                raise ValueError("The buffer interface is only available when "
                                 "a Lattice object uses a LexicoLayout.")
            out = np.asarray(self)
            out.dtype = complex
            out = out.reshape(tuple(self.layout.instance.shape()) + (self.site_size,) + (3, 3))
            out[:] = value

    def change_layout(self, Layout layout):
        if self.view_count != 0:
            raise ValueError("This object still has active memory views. "
                             "Delete them first and try again (using del)")

        if layout is self.layout:
            return

        if layout.shape != self.layout.shape:
            raise ValueError("Supplied Layout instance does not have the same "
                             "shape as the currentl layout.")

        self.instance.change_layout(layout.instance[0])
        self.layout = layout
        self.is_buffer_compatible = isinstance(layout, LexicoLayout)

    def __repr__(self):
        return self.as_numpy.__repr__()

cdef class ColourVector:
    """Statically-sized colour vector of shape (3,).

    Supports indexing and attribute lookup akin to the numpy.ndarray type.

    Attributes:
      as_numpy (numpy.ndarray): A numpy array view onto the underlying buffer
        containing the lattice data.
    """

    def __cinit__(self):
        """Constructor for ColourVector type. See help(ColourVector)."""
        self.instance = new _ColourVector(core._ColourVector_zeros())
        self.view_count = 0

    def __dealloc__(self):
        del self.instance

    def __getbuffer__(self, Py_buffer* buffer, int flags):
        cdef Py_ssize_t itemsize = sizeof(atomics.Complex)

        self.buffer_shape[0] = 3
        self.buffer_strides[0] = itemsize

        buffer.buf = <char*>self.instance

        buffer.format = "dd"
        buffer.internal = NULL
        buffer.itemsize = itemsize
        buffer.len = itemsize * 3
        buffer.ndim = 1

        buffer.obj = self
        buffer.readonly = 0
        buffer.shape = self.buffer_shape
        buffer.strides = self.buffer_strides
        buffer.suboffsets = NULL

        self.view_count += 1

    def __releasebuffer__(self, Py_buffer* buffer):
        self.view_count -= 1

    def __getitem__(self, index):
        return self.as_numpy[index]

    def __setitem__(self, index, value):
        if hasattr(value, 'as_numpy'):
            self.as_numpy[index] = value.as_numpy
        else:
            self.as_numpy[index] = value

    def __getattr__(self, attr):
        return getattr(self.as_numpy, attr)

    property as_numpy:
        def __get__(self):
            """numpy.ndarray: A numpy array view onto the underlying data buffer
            """
            out = np.asarray(self)
            out.dtype = complex
            return out.reshape((3,))

        def __set__(self, value):
            out = np.asarray(self)
            out.dtype = complex
            out = out.reshape((3,))
            out[:] = value

    def __repr__(self):
        return self.as_numpy.__repr__()

cdef class LatticeColourVector:
    """Lattice colour vector of specified shape.

    A LatticeColourVector instance is initialised with the specified lattice
    shape, with the specified number of colour vectors at each site.

    Supports indexing and attribute lookup akin to the numpy.ndarray type.

    Args:
      shape (tuple-like): The shape of the lattice.
      site_size (int): The number of colour vectors at each site.
    """

    def __cinit__(self, Layout layout, int site_size=1):
        """Constructor for LatticeColourVector type. See help(LatticeColourVector)."""
        self.layout = layout
        self.is_buffer_compatible = isinstance(layout, LexicoLayout)
        self.view_count = 0
        self.site_size = site_size
        self.instance = new _LatticeColourVector(layout.instance[0],  _ColourVector(_ColourVector_zeros()), site_size)

    def __dealloc__(self):
        del self.instance

    def __getbuffer__(self, Py_buffer* buffer, int flags):
        if not self.is_buffer_compatible:
            return

        cdef Py_ssize_t itemsize = sizeof(atomics.Complex)

        self.buffer_shape[0] = self.instance[0].volume() * self.site_size
        self.buffer_strides[0] = itemsize * 3
        self.buffer_shape[1] = 3
        self.buffer_strides[1] = itemsize

        buffer.buf = <char*>&(self.instance[0][0])

        buffer.format = "dd"
        buffer.internal = NULL
        buffer.itemsize = itemsize
        buffer.len = itemsize * 3 * self.instance[0].volume() * self.site_size
        buffer.ndim = 2

        buffer.obj = self
        buffer.readonly = 0
        buffer.shape = self.buffer_shape
        buffer.strides = self.buffer_strides
        buffer.suboffsets = NULL

        self.view_count += 1

    def __releasebuffer__(self, Py_buffer* buffer):
        self.view_count -= 1

    def __getitem__(self, index):
        return self.as_numpy[index]

    def __setitem__(self, index, value):
        if hasattr(value, 'as_numpy'):
            self.as_numpy[index] = value.as_numpy
        else:
            self.as_numpy[index] = value

    def __getattr__(self, attr):
        return getattr(self.as_numpy, attr)

    property as_numpy:
        def __get__(self):
            """numpy.ndarray: A numpy array view onto the underlying data buffer
            """
            if not self.is_buffer_compatible:
                raise ValueError("The buffer interface is only available when "
                                 "a Lattice object uses a LexicoLayout.")
            out = np.asarray(self)
            out.dtype = complex
            return out.reshape(tuple(self.layout.instance.shape()) + (self.site_size,) + (3,))

        def __set__(self, value):
            if not self.is_buffer_compatible:
                raise ValueError("The buffer interface is only available when "
                                 "a Lattice object uses a LexicoLayout.")
            out = np.asarray(self)
            out.dtype = complex
            out = out.reshape(tuple(self.layout.instance.shape()) + (self.site_size,) + (3,))
            out[:] = value

    def change_layout(self, Layout layout):
        if self.view_count != 0:
            raise ValueError("This object still has active memory views. "
                             "Delete them first and try again (using del)")

        if layout is self.layout:
            return

        if layout.shape != self.layout.shape:
            raise ValueError("Supplied Layout instance does not have the same "
                             "shape as the currentl layout.")

        self.instance.change_layout(layout.instance[0])
        self.layout = layout
        self.is_buffer_compatible = isinstance(layout, LexicoLayout)

    def __repr__(self):
        return self.as_numpy.__repr__()
