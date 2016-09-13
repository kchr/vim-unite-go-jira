let s:save_cpo = &cpo
set cpo&vim

let g:unite_source_output_shellcmd_colors =
      \ get(g:, 'unite_source_output_shellcmd_colors', [
      \ '#6c6c6c', '#ff6666', '#66ff66', '#ffd30a',
      \ '#1e95fd', '#ff13ff', '#1bc8c8', '#c0c0c0',
      \ '#383838', '#ff4444', '#44ff44', '#ffb30a',
      \ '#6699ff', '#f820ff', '#4ae2e2', '#ffffff',
      \])
"}}}

let s:unite_source = {
      \ 'name':           'jira',
      \ 'description':    'results from JIRA query',
      \ 'default_action': 'view',
      \ 'default_kind':   'jira_issue',
      \ 'hooks':          {},
      \ }

function! unite#sources#jira#define() abort "{{{
    return s:unite_source
endfunction "}}}

function! s:unite_source.hooks.on_init(args, context) abort "{{{
  let query = join(filter(copy(a:args), "v:val !=# '!'"))
  if query == ''
    let query = unite#util#input(
          \ 'JIRA query: ', '', 'shellcmd')
    redraw
  endif

  let a:context.source__query = query
  let a:context.source__command = "jira ls -q '" . query . "'"
  let a:context.source__is_dummy =
        \ (get(a:args, -1, '') ==# '!')

  " If source_is_dummy, print query
  if !a:context.source__is_dummy
      call unite#print_source_message(
            \ 'query: ' . query, s:unite_source.name)
  endif
endfunction "}}}

function! s:unite_source.gather_candidates(args, context) abort "{{{
  " Check that vimproc is available
  if !unite#util#has_vimproc()
    call unite#print_source_message(
          \ 'vimproc plugin is not installed.', self.name)
    let a:context.is_async = 0
    return []
  endif

  let cwd = getcwd()
  try
    if a:context.path != ''
      call unite#util#lcd(a:context.path)
    endif

    " Run the command
    let a:context.source__proc = vimproc#plineopen2(
          \ vimproc#util#iconv(
          \   a:context.source__command, &encoding, 'char'), 1)
  catch
    " Print exception and return empty list
    call unite#util#lcd(cwd)
    call unite#print_error(v:exception)

    let a:context.is_async = 0
    return []
  endtry

  return self.async_gather_candidates(a:args, a:context)
endfunction "}}}

function! s:unite_source.async_gather_candidates(args, context) abort "{{{
  let stdout = a:context.source__proc.stdout
  if stdout.eof
    " Disable async.
    let a:context.is_async = 0
    call a:context.source__proc.waitpid()
  endif

  " Get lines from the command output on stdout
  let lines = map(unite#util#read_lines(stdout, 1000),
        \ "substitute(unite#util#iconv(v:val, 'char', &encoding),
        \   '\\e\\[\\u', '', 'g')")

  " Return a hash map for the line and some metadata
  return map(lines, "{
        \ 'abbr'       : v:val,
        \ 'word'       : substitute(v:val, ':\s+', '', ''),
        \ 'jira_issue' : substitute(v:val, '\\e\\[[0-9;]*m', '', 'g'),
        \ 'is_dummy'   : a:context.source__is_dummy
        \ }")
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
