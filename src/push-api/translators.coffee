# translator is a function that accepts array of translatables
# and returns array of successful translations
# (see push-translator.coffee for details on objects).
#
# !!! IMPORTANT !!!
# Translators must never fail (log error-d items and skip them).
# Translators must always be async (setImmediate stuff if needed).
#
# arg types are of format "#{translatorId}:#{specific-info}". Exported object
# is keyed with TranslatorIDs and push-translator will use it to look up
# translators. For example, all the `directory:name` entries will
# be grouped into single array and passed to a function exported under
# `directory` key, like this:
#
#   require('./translatros')['directory'](translatabesArray, callback)
#
# It is translators job to correctly regroup all the translatables and
# issue appropriate number of requests.
#
# If translator is not found in exported objects, nothing will get translated,
# and original string will make it into resulting object.

module.exports = {}
