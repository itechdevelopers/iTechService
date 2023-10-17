jQuery ->
  inputField = $('.category-chosen-value')
  dropdown = $('.categories-value-list')
  dropdownArray = $('.categories-value-list li').toArray()
  valueArray = []
  manageCategoriesBtn = $('.wiki_wrapper #manage-categories')

  for item in dropdownArray
    valueArray.push $(item).text()

  inputField.on 'input', ->
    dropdown.addClass('open')
    inputValue = inputField.val().toLowerCase()
    if inputValue.length > 0
      for j in [0...valueArray.length]
        if !(inputValue.substring(0, inputValue.length) is valueArray[j].substring(0, inputValue.length).toLowerCase())
          $(dropdownArray[j]).addClass('closed')
        else
          $(dropdownArray[j]).removeClass('closed')
    else
      for i in [0..dropdownArray.length-1]
        $(dropdownArray[i]).removeClass('closed')

  for item in dropdownArray
    $(item).on 'click', (evt) ->
      inputField.val $(this).text()
      for i in dropdownArray
        $(i).addClass('closed')

  inputField.on 'focus', ->
    inputField.attr('placeholder', 'Создайте новую или выберите существующую')
    $(dropdown).addClass('open')
    for item in dropdownArray
      $(item).removeClass('closed')

  inputField.on 'blur', ->
    inputField.attr('placeholder', 'Введите категорию')
    $(dropdown).removeClass('open')

  manageCategoriesBtn.on 'click', ->
    $('.wiki_manage_categories').toggleClass('open')