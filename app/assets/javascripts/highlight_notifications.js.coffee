window.highlightPhrases = [
  'Новый комментарий к канбан карточке',
  'На вашей доске добавлена новая карточка',
  'Получено достижение'
]

window.highlightNotifications = ->
  $('.popover .single-notification').each ->
    $notification = $(this)
    $link = $notification.find('a').first()
    originalText = $link.html()
    
    for phrase in window.highlightPhrases
      if originalText.indexOf(phrase) >= 0
        boldPhrase = "<strong>#{phrase}</strong>"
        newText = originalText.replace(phrase, boldPhrase)
        $link.html(newText)
        break

$(document).ready ->
  window.highlightNotifications()
  
  window.observer = new MutationObserver (mutations) ->
    for mutation in mutations
      if mutation.addedNodes?.length
        for node in mutation.addedNodes
          if $(node).hasClass('popover') or $(node).find('.popover').length
            window.highlightNotifications()
            break
  
  window.observerConfig = 
    childList: true
    subtree: true
  
  window.observer.observe(document.body, window.observerConfig)
