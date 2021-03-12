function! wilder#highlight#merge_highlighters(highlighters)
  return {ctx, x, data -> s:merge_highlighters(a:highlighters, ctx, x, data)}
endfunction

function! s:merge_highlighters(highlighters, ctx, x, data)
  for l:Highlighter in a:highlighters
    let l:highlight = l:Highlighter(a:ctx, a:x, a:data)

    if l:highlight isnot 0
      return l:highlight
    endif
  endfor

  return 0
endfunction

function! wilder#highlight#query_highlighter(...)
  let l:opts = get(a:, 1, {})
  let l:language = get(l:opts, 'language', 'vim')

  if l:language ==# 'python'
    return {ctx, x, data -> wilder#highlight#python_highlight_query(ctx, l:opts, x, data)}
  endif

  return {ctx, x, data -> wilder#highlight#vim_highlight_query(ctx, l:opts, x, data)}
endfunction

function! wilder#highlight#vim_highlight_query(ctx, opts, x, data)
  if !has_key(a:data, 'query')
    return 0
  endif

  let l:query = a:data['query']
  let l:case_sensitive = get(a:opts, 'case_sensitive', 0)

  let l:split_str = split(a:x, '\zs')
  let l:split_query = split(l:query, '\zs')

  let l:spans = []
  let l:span = [-1, 0]

  let l:byte_pos = 0
  let l:i = 0
  let l:j = 0
  while l:i < len(l:split_str) && l:j < len(l:split_query)
    let l:str_len = strlen(l:split_str[l:i])

    if l:case_sensitive
      let l:match = l:split_str[l:i] ==# l:split_query[l:j]
    else
      let l:match = l:split_str[l:i] ==? l:split_query[l:j]
    endif

    if l:match
      let l:j += 1

      if l:span[0] == -1
        let l:span[0] = l:byte_pos
      endif

      let l:span[1] += l:str_len
    endif

    if !l:match && l:span[0] != -1
      call add(l:spans, l:span)
      let l:span = [-1, 0]
    endif

    let l:byte_pos += l:str_len
    let l:i += 1
  endwhile

  if l:span[0] != -1
    call add(l:spans, l:span)
  endif

  return l:spans
endfunction

function! wilder#highlight#python_highlight_query(ctx, opts, x, data)
  if !has_key(a:data, 'query')
    return 0
  endif

  let l:query = a:data['query']
  let l:case_sensitive = get(a:opts, 'case_sensitive', 0)

  return _wilder_python_common_subsequence_spans(a:str, a:query, a:case_sensitive)
endfunction

function! wilder#highlight#pcre2_highlighter(...)
  let l:opts = get(a:, 1, {})
  let l:language = get(l:opts, 'language', 'python')

  if l:language ==# 'lua'
    return {ctx, x, data -> wilder#highlight#lua_highlight_pcre2(ctx, l:opts, x, data)}
  endif

  return {ctx, x, data -> wilder#highlight#python_highlight_pcre2(ctx, l:opts, x, data)}
endfunction

function! wilder#highlight#python_highlight_pcre2(ctx, opts, x, data)
  if !has_key(a:data, 'pcre2.pattern')
    return 0
  endif

  let l:pattern = a:data['pcre2.pattern']
  let l:engine = get(a:opts, 'engine', 're')

  return _wilder_python_pcre2_capture_spans(l:pattern, a:x, l:engine)
endfunction

function! wilder#highlight#lua_highlight_pcre2(ctx, opts, x, data)
  if !has_key(a:data, 'pcre2.pattern')
    return 0
  endif

  let l:pattern = a:data['pcre2.pattern']

  let l:spans = luaeval(
        \ 'require("wilder").pcre2_capture_spans(_A[1], _A[2])',
        \ [l:pattern, a:x])

  " remove first element which is the matched string
  " convert from [{start+1}, {end+1}] to [{start}, {len}]
  return map(l:spans[1:], {i, s -> [s[0] - 1, s[1] - s[0] + 1]})
endfunction