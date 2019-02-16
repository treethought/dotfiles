﻿import __builtin__ as _mod___builtin__
import exceptions as _mod_exceptions

PyCFuncPtr = PyCFuncPtrType()
class ArgumentError(_mod_exceptions.Exception):
    __class__ = ArgumentError
    __dict__ = {}
    def __init__(self):
        'x.__init__(...) initializes x; see help(type(x)) for signature'
        pass

    __module__ = 'ctypes'
    @classmethod
    def __subclasshook__(cls, subclass):
        'Abstract classes can override this to customize issubclass().\n\nThis is invoked early on by abc.ABCMeta.__subclasscheck__().\nIt should return True, False or NotImplemented.  If it returns\nNotImplemented, the normal algorithm is used.  Otherwise, it\noverrides the normal algorithm (and the outcome is cached).\n'
        return False

    @property
    def __weakref__(self):
        'list of weak references to the object (if defined)'
        pass


class Array(_CData):
    'XXX to be provided'
    __class__ = Array
    def __delitem__(self):
        'x.__delitem__(y) <==> del x[y]'
        return None

    def __delslice__(self):
        'x.__delslice__(i, j) <==> del x[i:j]\n           \n           Use of negative indices is not supported.'
        pass

    def __getitem__(self, index):
        'x.__getitem__(y) <==> x[y]'
        pass

    def __getslice__(self):
        'x.__getslice__(i, j) <==> x[i:j]\n           \n           Use of negative indices is not supported.'
        return Array()

    def __init__(self):
        'x.__init__(...) initializes x; see help(type(x)) for signature'
        pass

    def __len__(self):
        'x.__len__() <==> len(x)'
        return 0

    def __setitem__(self, index, value):
        'x.__setitem__(i, y) <==> x[i]=y'
        return None

    def __setslice__(self):
        'x.__setslice__(i, j, y) <==> x[i:j]=y\n           \n           Use  of negative indices is not supported.'
        pass

    @classmethod
    def __subclasshook__(cls, subclass):
        'Abstract classes can override this to customize issubclass().\n\nThis is invoked early on by abc.ABCMeta.__subclasscheck__().\nIt should return True, False or NotImplemented.  If it returns\nNotImplemented, the normal algorithm is used.  Otherwise, it\noverrides the normal algorithm (and the outcome is cached).\n'
        return False


CFuncPtr = PyCFuncPtr()
FUNCFLAG_CDECL = 1
FUNCFLAG_PYTHONAPI = 4
FUNCFLAG_USE_ERRNO = 8
FUNCFLAG_USE_LASTERROR = 16
def POINTER():
    pass

def PyObj_FromPtr():
    pass

def Py_DECREF():
    pass

def Py_INCREF():
    pass

RTLD_GLOBAL = 8
RTLD_LOCAL = 4
class Structure(_CData):
    'Structure base class'
    __class__ = Structure
    def __init__(self):
        'x.__init__(...) initializes x; see help(type(x)) for signature'
        pass

    @classmethod
    def __subclasshook__(cls, subclass):
        'Abstract classes can override this to customize issubclass().\n\nThis is invoked early on by abc.ABCMeta.__subclasscheck__().\nIt should return True, False or NotImplemented.  If it returns\nNotImplemented, the normal algorithm is used.  Otherwise, it\noverrides the normal algorithm (and the outcome is cached).\n'
        return False


class Union(_CData):
    'Union base class'
    __class__ = Union
    def __init__(self):
        'x.__init__(...) initializes x; see help(type(x)) for signature'
        pass

    @classmethod
    def __subclasshook__(cls, subclass):
        'Abstract classes can override this to customize issubclass().\n\nThis is invoked early on by abc.ABCMeta.__subclasscheck__().\nIt should return True, False or NotImplemented.  If it returns\nNotImplemented, the normal algorithm is used.  Otherwise, it\noverrides the normal algorithm (and the outcome is cached).\n'
        return False


class _Pointer(_CData):
    'XXX to be provided'
    __class__ = _Pointer
    def __delitem__(self):
        'x.__delitem__(y) <==> del x[y]'
        return None

    def __getitem__(self, index):
        'x.__getitem__(y) <==> x[y]'
        pass

    def __getslice__(self):
        'x.__getslice__(i, j) <==> x[i:j]\n           \n           Use of negative indices is not supported.'
        return _Pointer()

    def __init__(self):
        'x.__init__(...) initializes x; see help(type(x)) for signature'
        pass

    def __nonzero__(self):
        'x.__nonzero__() <==> x != 0'
        pass

    def __setitem__(self, index, value):
        'x.__setitem__(i, y) <==> x[i]=y'
        return None

    @classmethod
    def __subclasshook__(cls, subclass):
        'Abstract classes can override this to customize issubclass().\n\nThis is invoked early on by abc.ABCMeta.__subclasscheck__().\nIt should return True, False or NotImplemented.  If it returns\nNotImplemented, the normal algorithm is used.  Otherwise, it\noverrides the normal algorithm (and the outcome is cached).\n'
        return False

    @property
    def contents(self):
        'the object this pointer points to (read-write)'
        pass


class _SimpleCData(_CData):
    'XXX to be provided'
    __class__ = _SimpleCData
    def __ctypes_from_outparam__(self):
        pass

    def __init__(self):
        'x.__init__(...) initializes x; see help(type(x)) for signature'
        pass

    def __nonzero__(self):
        'x.__nonzero__() <==> x != 0'
        pass

    def __repr__(self):
        'x.__repr__() <==> repr(x)'
        return ''

    @classmethod
    def __subclasshook__(cls, subclass):
        'Abstract classes can override this to customize issubclass().\n\nThis is invoked early on by abc.ABCMeta.__subclasscheck__().\nIt should return True, False or NotImplemented.  If it returns\nNotImplemented, the normal algorithm is used.  Otherwise, it\noverrides the normal algorithm (and the outcome is cached).\n'
        return False

    @property
    def value(self):
        'current value'
        pass


__doc__ = 'Create and manipulate C compatible data types in Python.'
__file__ = '/System/Library/Frameworks/Python.framework/Versions/2.7/lib/python2.7/lib-dynload/_ctypes.so'
__name__ = '_ctypes'
__package__ = None
__version__ = '1.1.0'
def _buffer_info():
    'Return buffer interface information (for testing only)'
    pass

_cast_addr = 4341257202
_memmove_addr = 140734862603728
_memset_addr = 140734862603734
_pointer_type_cache = _mod___builtin__.dict()
_string_at_addr = 4341257178
def _unpickle():
    pass

_wstring_at_addr = 4341257680
def addressof(Cinstance):
    'addressof(C instance) -> integer\nReturn the address of the C instance internal buffer'
    return 1

def alignment(Cinstance):
    'alignment(C type) -> integer\nalignment(C instance) -> integer\nReturn the alignment requirements of a C instance'
    return 1

def byref(Cinstance, offset=0):
    'byref(C instance[, offset=0]) -> byref-object\nReturn a pointer lookalike to a C instance, only usable\nas function argument'
    pass

def call_cdeclfunction():
    pass

def call_function():
    pass

def dlclose():
    'dlclose a library'
    pass

def dlopen(name, flag={RTLD_GLOBAL|RTLD_LOCAL}):
    'dlopen(name, flag={RTLD_GLOBAL|RTLD_LOCAL}) open a shared library'
    pass

def dlsym():
    'find symbol in shared library'
    pass

def get_errno():
    pass

def pointer():
    pass

def resize():
    'Resize the memory buffer of a ctypes instance'
    pass

def set_conversion_mode(encoding, errors):
    'set_conversion_mode(encoding, errors) -> (previous-encoding, previous-errors)\n\nSet the encoding and error handling ctypes uses when converting\nbetween unicode and strings.  Returns the previous values.\n'
    return tuple()

def set_errno():
    pass

def sizeof(Cinstance):
    'sizeof(C type) -> integer\nsizeof(C instance) -> integer\nReturn the size in bytes of a C instance'
    return 1

