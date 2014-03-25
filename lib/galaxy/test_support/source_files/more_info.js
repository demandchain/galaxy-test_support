function show_more_info (event_obj)
{
  content_item = $ (event_obj.target).closest (".test-support-row").find (".hide-contents");
  expand_item = $ (event_obj.target).closest (".test-support-row").find (".test-support-cell-expand div a img");
  more_item = $ (event_obj.target).closest (".test-support-row").find (".test-support-cell-more");

  if (content_item.attr ("class").match (/truncated-text/))
  {
    content_item.removeClass ("truncated-text");
    expand_item.attr ("src", "collapse.gif");
    more_item.addClass ("hidden");
  }
  else
  {
    content_item.addClass ("truncated-text");
    expand_item.attr ("src", "expand.gif");
    more_item.removeClass ("hidden");
  }
}

$ (document).ready (function ()
    {
      $ (document).on ("click", "a", {}, show_more_info);

      hide_contents = $ (".hide-contents");
      for (nIndex = hide_contents.length - 1; nIndex >= 0; nIndex -= 1)
      {
        hide_obj = $ (hide_contents[nIndex]);
        if (hide_obj.height () > 100)
        {
          expand_item = hide_obj.closest (".test-support-row").find (".test-support-cell-expand div");
          more_item = hide_obj.closest (".test-support-row").find (".test-support-cell-more");
          hide_obj.addClass ("truncated-text");
          expand_item.removeClass ("hidden");
          more_item.removeClass ("hidden");
        }
      }
    }
);