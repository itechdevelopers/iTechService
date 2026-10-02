# "Show all" for a transcription summary clamped to three lines by CSS. Whether the text fits is
# known only after layout, so the toggle is revealed by comparing scrollHeight with the clamped
# height. Expanded summaries are skipped: they no longer overflow, and re-checking them would hide
# the very toggle that collapses them back.
markOverflowingSummaries = ->
  $('.call-transcription-summary').not('.call-transcription-summary--expanded').each ->
    text = $(this).find('.call-transcription-summary__text')[0]
    $(this).toggleClass('call-transcription-summary--overflowing', text.scrollHeight > text.clientHeight + 1)

$ ->
  markOverflowingSummaries()
  # Table columns change width with the window, and with them the number of lines
  $(window).on 'resize', markOverflowingSummaries

$(document).on 'click', '.call-transcription-summary__toggle', (event) ->
  event.preventDefault()
  $summary = $(this).closest('.call-transcription-summary')
  $summary.toggleClass('call-transcription-summary--expanded')
  expanded = $summary.hasClass('call-transcription-summary--expanded')
  $(this).text($(this).data(if expanded then 'collapse-text' else 'expand-text'))
