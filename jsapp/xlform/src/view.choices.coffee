_ = require 'underscore'
Backbone = require 'backbone'
$choices = require './model.choices'
$modelUtils = require './model.utils'
$baseView = require './view.pluggedIn.backboneView'
$viewTemplates = require './view.templates'
$viewUtils = require './view.utils'
_t = require('utils').t

module.exports = do ->
  class ListView extends $baseView
    initialize: ({@rowView, @model})->
      @list = @model
      @row = @rowView.model
      $($.parseHTML $viewTemplates.row.selectQuestionExpansion()).insertAfter @rowView.$('.card__header')
      @$el = @rowView.$(".list-view")
      @ulClasses = @$("ul").prop("className")
      @mediametadata = this.rowView.options.surveyView.appState.mediametadata

    render: ->
      cardText = @rowView.$el.find('.card__text')
      if cardText.find('.card__buttons__multioptions.js-expand-multioptions').length is 0
        cardText.prepend $.parseHTML($viewTemplates.row.expandChoiceList())
      @$el.html (@ul = $("<ul>", class: @ulClasses))
      if @row.get("type").get("rowType").specifyChoice
        for option, i in @model.options.models
           option.mediameta = this.mediametadata
          new OptionView(model: option, cl: @model).render().$el.appendTo @ul
        if i == 0
          while i < 2
            @addEmptyOption("Option #{++i}")

        @$el.removeClass("hidden")
      else
        @$el.addClass("hidden")
      @ul.sortable({
          axis: "y"
          cursor: "move"
          distance: 5
          items: "> li"
          placeholder: "option-placeholder"
          opacity: 0.9
          scroll: false
          deactivate: =>
            if @hasReordered
              @reordered()
              @model.getSurvey()?.trigger('change')
            true
          change: => @hasReordered = true
        })
      btn = $($viewTemplates.$$render('xlfListView.addOptionButton'))
      btn.click(() =>
        i = @model.options.length
        @addEmptyOption("Option #{i+1}")
        @model.getSurvey()?.trigger('change')
        @$el.children().eq(0).children().eq(i).find('input.option-view-input').select()
      )

      @$el.append(btn)
      return @

    addEmptyOption: (label)->
      emptyOpt = new $choices.Option(label: label)
      emptyOpt.mediameta = this.mediametadata
      @model.options.add(emptyOpt)
      new OptionView(model: emptyOpt, cl: @model).render().$el.appendTo @ul
      lis = @ul.find('li')
      if lis.length == 2
        lis.find('.js-remove-option').removeClass('hidden')

    reordered: (evt, ui)->
      ids = []
      @ul.find("> li").each (i,li)=>
        lid = $(li).data("optionId")
        if lid
          ids.push lid
      for id, n in ids
        @model.options.get(id).set("order", n, silent: true)
      @model.options.comparator = "order"
      @model.options.sort()
      @hasReordered = false

  class OptionView extends $baseView
    tagName: "li"
    className: "multioptions__option xlf-option-view xlf-option-view--depr"
    events:
      "keyup input": "keyupinput"
      "keydown input": "keydowninput"
      "click .js-remove-option": "remove"
    initialize: (@options)->
      @options = @options
    render: ->
      @t = $("<i class=\"fa fa-trash-o js-remove-option\">")
      @pw = $("<div class=\"editable-wrapper js-cancel-select-row\">")
      @p = $("<input placeholder=\"#{_t("This option has no name")}\" class=\"js-cancel-select-row option-view-input\">")
      @c = $("<code><label>#{_t('Value:')}</label> <span class=\"js-cancel-select-row\">#{_t('AUTOMATIC')}</span></code>") 
      @c2 = $("<code><label>#{_t('Media')}</label> <select class=\"js-cancel-select-row\"></select></code>") 

      @b = $("<div><input type='text' value=''></input></div>")
      @s = $("<div class=\"media-option-select\"><label>#{_t('Media')}</label><select ></select></div>")
      @d = $('<div>')
      if @model
        @p.val @model.get("label") || 'Empty'
        @$el.attr("data-option-id", @model.cid)
        $('input', @c).val @model.get("name") || 'AUTOMATIC'
        $('input', this.b).attr('value', @model.get("media::image")) 

        if (this.model.mediameta && this.model.mediameta.length > 0)
           # $('code', this.c2).removeClass("hidden")
            option = new Option("None", "")        
            $('select', this.c2).append(option)

            for media in @model.mediameta 
                option = new Option(media.data_value, media.data_value) 
                if(media.data_value == @model.get("media::image"))
                    option.selected = "true"                      
                $('select', this.c2).append(option)

            # if could not match media::image, the image may have
            # been removed from project settings so reset to null 
            if ( $('select', this.c2).length > 0 &&  $('select', this.c2)[0].selectedIndex == 0 ) 
                @model.set("media::image","" ) 


        #else
           # $(this.c2).addClass("hidden")
        @model.set('setManually', true)
      else
        @model = new $choices.Option()
        @options.cl.options.add(@model)
        @p.val("Option #{1+@options.i}").addClass("preliminary")

      @p.change ((input)->
        nval = input.currentTarget.value
        @saveValue(nval)
      ).bind @

      @n = $('input', @c)
      @n.change ((input)->
        val = input.currentTarget.value
        other_names = @options.cl.getNames()
        if @model.get('name')? && val.toLowerCase() == @model.get('name').toLowerCase()
          other_names.splice _.indexOf(other_names, @model.get('name')), 1
        if val is ''
          @model.unset('name')
          @model.set('setManually', false)
          val = 'AUTOMATIC'
          @$el.trigger("choice-list-update", @options.cl.cid)
        else
          val = $modelUtils.sluggify(val, {
                    preventDuplicates: other_names
                    lowerCase: false
                    lrstrip: true
                    incrementorPadding: false
                    characterLimit: 40
                    validXmlTag: false
                    nonWordCharsExceptions: '+-.'
                  })
          @model.set('name', val)
          @model.set('setManually', true)
          @$el.trigger("choice-list-update", @options.cl.cid)
        newValue: val
      ).bind @
      @pw.html(@p)

      $('input', this.b).on 'change' , (event) => 
          @model.set("media::image",event.target.value )

      $('select', this.c2).on 'change' , (event) => 
          @model.set("media::image",event.target.value )

      @pw.on 'click', (event) =>
        if !@p.is(':hidden') && event.target != @p[0]
          @p.click()

      @d.append(@pw)
      @d.append(@t)
      @d.append(@c)
      @d.append(@c2)
      @$el.html(@d)
      @
    keyupinput: (evt)->
      ifield = @$("input.inplace_field")
      if evt.keyCode is 8 and ifield.hasClass("empty")
        ifield.blur()

      if ifield.val() is ""
        ifield.addClass("empty")
      else
        ifield.removeClass("empty")

    keydowninput: (evt) ->
      if evt.keyCode is 13
        evt.preventDefault()

        localListViewIndex = $('ul.ui-sortable').index($(this.el).parent())
        localOptionView = $('ul.ui-sortable').eq(localListViewIndex).children().find('input.option-view-input')
        index = localOptionView.index(document.activeElement) + 1

        if index >= localOptionView.length
          $(this.el).parent().siblings().find('div.editable-wrapper').eq(0).focus()

        localOptionView.eq(index).select()

    remove: ()->
      $parent = @$el.parent()

      @model.getSurvey()?.trigger('change')

      @$el.remove()
      @model.destroy()

      lis = $parent.find('li')
      if lis.length == 1
        lis.find('.js-remove-option').addClass('hidden')

    saveValue: (nval)->
      # if new value has no non-space characters, it is invalid
      unless "#{nval}".match /\S/
        nval = false

      if nval
        nval = nval.replace /\t/g, ' '
        @model.set("label", nval, silent: true)
        other_names = @options.cl.getNames()
        if !@model.get('setManually')
          sluggifyOpts =
            preventDuplicates: other_names
            lowerCase: false
            stripSpaces: true
            lrstrip: true
            incrementorPadding: 3
            validXmlTag: true
          @model.set("name", $modelUtils.sluggify(nval, sluggifyOpts))
        @$el.trigger("choice-list-update", @options.cl.cid)
        @model.getSurvey()?.trigger('change')
        return
      else
        return newValue: @model.get "label"

  ListView: ListView
  OptionView: OptionView
