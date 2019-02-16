﻿import __builtin__ as _mod___builtin__
import exceptions as _mod_exceptions

class ZipImportError(_mod_exceptions.ImportError):
    __class__ = ZipImportError
    __dict__ = {}
    def __init__(self):
        'x.__init__(...) initializes x; see help(type(x)) for signature'
        pass

    __module__ = 'zipimport'
    @classmethod
    def __subclasshook__(cls, subclass):
        'Abstract classes can override this to customize issubclass().\n\nThis is invoked early on by abc.ABCMeta.__subclasscheck__().\nIt should return True, False or NotImplemented.  If it returns\nNotImplemented, the normal algorithm is used.  Otherwise, it\noverrides the normal algorithm (and the outcome is cached).\n'
        return False

    @property
    def __weakref__(self):
        'list of weak references to the object (if defined)'
        pass


__doc__ = "zipimport provides support for importing Python modules from Zip archives.\n\nThis module exports three objects:\n- zipimporter: a class; its constructor takes a path to a Zip archive.\n- ZipImportError: exception raised by zipimporter objects. It's a\n  subclass of ImportError, so it can be caught as ImportError, too.\n- _zip_directory_cache: a dict, mapping archive paths to zip directory\n  info dicts, as used in zipimporter._files.\n\nIt is usually not needed to use the zipimport module explicitly; it is\nused by the builtin import mechanism for sys.path items that are paths\nto Zip archives."
__name__ = 'zipimport'
__package__ = None
_zip_directory_cache = _mod___builtin__.dict()
class zipimporter(_mod___builtin__.object):
    "zipimporter(archivepath) -> zipimporter object\n\nCreate a new zipimporter instance. 'archivepath' must be a path to\na zipfile, or to a specific path inside a zipfile. For example, it can be\n'/tmp/myimport.zip', or '/tmp/myimport.zip/mydirectory', if mydirectory is a\nvalid directory inside the archive.\n\n'ZipImportError is raised if 'archivepath' doesn't point to a valid Zip\narchive.\n\nThe 'archive' attribute of zipimporter objects contains the name of the\nzipfile targeted."
    __class__ = zipimporter
    def __getattribute__(self):
        "x.__getattribute__('name') <==> x.name"
        pass

    def __init__(self, archivepath):
        'x.__init__(...) initializes x; see help(type(x)) for signature'
        pass

    def __repr__(self):
        'x.__repr__() <==> repr(x)'
        return ''

    @classmethod
    def __subclasshook__(cls, subclass):
        'Abstract classes can override this to customize issubclass().\n\nThis is invoked early on by abc.ABCMeta.__subclasscheck__().\nIt should return True, False or NotImplemented.  If it returns\nNotImplemented, the normal algorithm is used.  Otherwise, it\noverrides the normal algorithm (and the outcome is cached).\n'
        return False

    @property
    def _files(self):
        pass

    @property
    def archive(self):
        pass

    def find_module(self, fullname, path=None):
        "find_module(fullname, path=None) -> self or None.\n\nSearch for a module specified by 'fullname'. 'fullname' must be the\nfully qualified (dotted) module name. It returns the zipimporter\ninstance itself if the module was found, or None if it wasn't.\nThe optional 'path' argument is ignored -- it's there for compatibility\nwith the importer protocol."
        pass

    def get_code(self, fullname):
        "get_code(fullname) -> code object.\n\nReturn the code object for the specified module. Raise ZipImportError\nif the module couldn't be found."
        pass

    def get_data(self, pathname):
        "get_data(pathname) -> string with file data.\n\nReturn the data associated with 'pathname'. Raise IOError if\nthe file wasn't found."
        return ''

    def get_filename(self, fullname):
        'get_filename(fullname) -> filename string.\n\nReturn the filename for the specified module.'
        pass

    def get_source(self, fullname):
        "get_source(fullname) -> source string.\n\nReturn the source code for the specified module. Raise ZipImportError\nif the module couldn't be found, return None if the archive does\ncontain the module, but has no source for it."
        pass

    def is_package(self, fullname):
        "is_package(fullname) -> bool.\n\nReturn True if the module specified by fullname is a package.\nRaise ZipImportError if the module couldn't be found."
        return True

    def load_module(self, fullname):
        "load_module(fullname) -> module.\n\nLoad the module specified by 'fullname'. 'fullname' must be the\nfully qualified (dotted) module name. It returns the imported\nmodule, or raises ZipImportError if it wasn't found."
        pass

    @property
    def prefix(self):
        pass


