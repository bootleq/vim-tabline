tabline.vim
===========

Tab pages line (['tabline'][], not GUI tab labels) customization.

  - Change tab label text with tab number, buffer name, .etc.
  - Tab min-width, max-width.
  - Extra color groups.
  - Expose tabline info as a variable (`tabline#tabs()`).


Screenshot
----------

![basic demo][]


Options
-------

Option variables and their default values:

```vim
g:tab_min_width          = 0
g:tab_max_width          = 40           " label longer then this will be chopped
g:tab_min_shrinked_width = 15           " when space is not enough, how much a tab can be shrinked
g:scroll_off             = 5            " how many tabs should appear before/after current tab
g:divide_equally         = 0            " boolean, try divide each tab equal-width
g:ellipsis_text          = '…'          " when chopped tab, use this as replacement text
g:nofile_text            = '[Scratch]'  " label for 'nofile' buffer
g:prompt_text            = ''           " label for 'prompt' buffer, leave blank will auto grab from `:ls!`
g:qf_text                = ''
g:new_file_text          = '[New]'      " when no filename, no matched buftype, will fallback to this
g:modified_text          = '+'          " Flag to indicate the file is modified
```


Similar Projects
----------------

- [taboo][] by @gcmt
- [tabulous][] by @webdevel


['tabline']: http://vimdoc.sourceforge.net/htmldoc/options.html#%27tabline%27
[taboo]: https://github.com/gcmt/taboo.vim
[tabulous]: https://github.com/webdevel/tabulous
[basic demo]: https://lh3.googleusercontent.com/-B_rqhR4JVY0/UQx32RGtDpI/AAAAAAAAB3E/rL1buFxcQS8/s1600/vim-tabline-130202.png
