﻿import builtins as _mod_builtins

E2BIG = 7
EACCES = 13
EADDRINUSE = 48
EADDRNOTAVAIL = 49
EAFNOSUPPORT = 47
EAGAIN = 35
EALREADY = 37
EAUTH = 80
EBADARCH = 86
EBADEXEC = 85
EBADF = 9
EBADMACHO = 88
EBADMSG = 94
EBADRPC = 72
EBUSY = 16
ECANCELED = 89
ECHILD = 10
ECONNABORTED = 53
ECONNREFUSED = 61
ECONNRESET = 54
EDEADLK = 11
EDESTADDRREQ = 39
EDEVERR = 83
EDOM = 33
EDQUOT = 69
EEXIST = 17
EFAULT = 14
EFBIG = 27
EFTYPE = 79
EHOSTDOWN = 64
EHOSTUNREACH = 65
EIDRM = 90
EILSEQ = 92
EINPROGRESS = 36
EINTR = 4
EINVAL = 22
EIO = 5
EISCONN = 56
EISDIR = 21
ELOOP = 62
EMFILE = 24
EMLINK = 31
EMSGSIZE = 40
EMULTIHOP = 95
ENAMETOOLONG = 63
ENEEDAUTH = 81
ENETDOWN = 50
ENETRESET = 52
ENETUNREACH = 51
ENFILE = 23
ENOATTR = 93
ENOBUFS = 55
ENODATA = 96
ENODEV = 19
ENOENT = 2
ENOEXEC = 8
ENOLCK = 77
ENOLINK = 97
ENOMEM = 12
ENOMSG = 91
ENOPOLICY = 103
ENOPROTOOPT = 42
ENOSPC = 28
ENOSR = 98
ENOSTR = 99
ENOSYS = 78
ENOTBLK = 15
ENOTCONN = 57
ENOTDIR = 20
ENOTEMPTY = 66
ENOTRECOVERABLE = 104
ENOTSOCK = 38
ENOTSUP = 45
ENOTTY = 25
ENXIO = 6
EOPNOTSUPP = 102
EOVERFLOW = 84
EOWNERDEAD = 105
EPERM = 1
EPFNOSUPPORT = 46
EPIPE = 32
EPROCLIM = 67
EPROCUNAVAIL = 76
EPROGMISMATCH = 75
EPROGUNAVAIL = 74
EPROTO = 100
EPROTONOSUPPORT = 43
EPROTOTYPE = 41
EPWROFF = 82
ERANGE = 34
EREMOTE = 71
EROFS = 30
ERPCMISMATCH = 73
ESHLIBVERS = 87
ESHUTDOWN = 58
ESOCKTNOSUPPORT = 44
ESPIPE = 29
ESRCH = 3
ESTALE = 70
ETIME = 101
ETIMEDOUT = 60
ETOOMANYREFS = 59
ETXTBSY = 26
EUSERS = 68
EWOULDBLOCK = 35
EXDEV = 18
__doc__ = "This module makes available standard errno system symbols.\n\nThe value of each symbol is the corresponding integer value,\ne.g., on most systems, errno.ENOENT equals the integer 2.\n\nThe dictionary errno.errorcode maps numeric codes to symbol names,\ne.g., errno.errorcode[2] could be the string 'ENOENT'.\n\nSymbols that are not relevant to the underlying system are not defined.\n\nTo map error codes to error messages, use the function os.strerror(),\ne.g. os.strerror(2) could return 'No such file or directory'."
__name__ = 'errno'
__package__ = ''
errorcode = _mod_builtins.dict()
