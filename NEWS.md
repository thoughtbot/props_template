# News

## 0.30.0 (Nov 25, 2023)

* PropsTemplate will no longer automatically `camelize(:lower)` on keys.
Instead, be explicit about the keys we're serializing.

For example: `json.currentUser` instead of `json.current_user`. This
is backward breaking. To retain the current behavior, you can do this:

```
module PropsTemplateOverride
  def format_key(key)
    @key_cache ||= {}
    @key_cache[key] ||= key.camelize(:lower)
    @key_cache[key]
  end

  def result!
    result = super
    @key_cache = {}
    result
  end

  ::Props::BaseWithExtensions.prepend self
end
```

## 0.24.0 (Nov 4th, 2023)
  * Turn the local assigns `virtual_path_of_template` that didn't work into a method on the view

## 0.23.0 (Jun 28, 2023)
  * Fix #1 issues templates without layouts were not rendering
  * Refactor layout_patch to make a less invasive monkey patch
  * Add ruby standard
  * Add CONTRIBUTING.md

## 0.21.1 (Jan 6, 2022)
  * Add support for Rails 7

## 0.21.0 (Jan 3, 2022)
  * rename bzq to props_at

## 0.20.0 (June 6, 2021)
  * Added testing for Ruby 3.0
  * Moved PropsTemplate to own repo
  * Use version.rb instead of VERSION file.
