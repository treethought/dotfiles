﻿__doc__ = None
__file__ = '/Users/cam/.local/share/virtualenvs/backend-RECL93nZ/lib/python3.7/site-packages/markupsafe/_speedups.cpython-37m-darwin.so'
__name__ = 'markupsafe._speedups'
__package__ = 'markupsafe'
def escape(s):
    'escape(s) -> markup\n\nConvert the characters &, <, >, \', and " in string s to HTML-safe\nsequences.  Use this if you need to display text that might contain\nsuch characters in HTML.  Marks return value as markup string.'
    pass

def escape_silent(s):
    'escape_silent(s) -> markup\n\nLike escape but converts None to an empty string.'
    pass

def soft_unicode(object):
    "soft_unicode(object) -> string\n\nMake a string unicode if it isn't already.  That way a markup\nstring is not converted back to unicode."
    return ''

