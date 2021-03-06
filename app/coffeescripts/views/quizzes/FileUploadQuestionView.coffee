define [
  'Backbone',
  'jquery',
  'jst/quizzes/fileUploadQuestionState',
  'jst/quizzes/fileUploadedOrRemoved',
  'underscore',
  'jquery.instructure_forms',
  'jquery.disableWhileLoading'
], ({Model,View}, $, template,uploadedOrRemovedTemplate,_) ->

  class FileUploadQuestion extends View

    # TODO: Handle quota errors?
    # TODO: Handle upload errors?

    els:
      '.file-upload': '$fileUpload'
      '.file-upload-btn': '$fileDialogButton'
      '.attachment-id': '$attachmentID'
      '.file-upload-box': '$fileUploadBox'

    events:
      'change input[type=file]': 'checkForFileChange'
      'click .file-upload-btn': 'openFileBrowser'
      'click .delete-attachment': 'deleteAttachment'

    checkForFileChange: (event) =>
      # Stop the bubbling of the event so the question doesn't
      # get marked as read before the file is uploaded.
      event.preventDefault()
      event.stopPropagation()
      if val = @$('.file-upload').val()
        @deferred = new $.Deferred()
        @removeFileStatusMessage()
        @$fileUploadBox.disableWhileLoading(@deferred)
        @uploadAttachment()

    uploadAttachment: =>
      el = $('.file-upload')[0]
      name = (el.value || el.name).split(/(\/|\\)/).pop()
      opts = name: name, on_duplicate: 'rename'
      $.ajaxJSON ENV.UPLOAD_URL,'POST',opts,
        # success
        (data) =>
          model = new Model data.upload_params
          $(el).attr('name', data.file_param)
          model.set('file', el)
          model.url = -> data.upload_url
          model.save null,
            multipart: el
            onlyGivenParameters: true
            success: (model) => @processAttachments [model.toJSON()]
            error: (err) =>
        ,(err) =>
          console.log(err)

    openFileBrowser: (event) =>
      event.preventDefault()
      @$fileUpload.click()

    render: =>
      super
      model = @model || {}
      # This unfortunate bit of browser detection is here because IE9
      # will throw an error if you programatically call "click" on the
      # input file element, get the file element, and submit a form.
      # For now, remove the input rendered in ERB-land, and the template is
      # responsible for rendering a fallback to a regular input type=file
      model.isIE = !!$.browser.msie
      if model.isIE
        @$('.file-upload').remove()
      @$fileUploadBox.html template model
      this

    removeFileStatusMessage: =>
      @$fileUploadBox.siblings('.file-status').remove()

    # For now we'll just process the first one.
    processAttachments: (attachments) =>
      @deferred.resolve()
      [@model,__] = attachments
      @$attachmentID.val(@model.id).trigger 'change'
      @$fileUploadBox.addClass 'file-upload-box-with-file'
      @render()
      @$fileUploadBox.parent().append uploadedOrRemovedTemplate(
        _.extend({},@model,{fileUploaded: true})
      )

    # For now we'll just remove it from the form, but not actually delete it
    # using the API in case teacher's need to see any uploaded files a
    # student may upload.
    deleteAttachment: (event) =>
      event.preventDefault()
      @$attachmentID.val("").trigger 'change'
      @$fileUploadBox.removeClass 'file-upload-box-with-file'
      oldModel = @model
      @model = {}
      @removeFileStatusMessage()
      @render()
      @$fileUploadBox.parent().append uploadedOrRemovedTemplate(
        _.extend({},oldModel,{fileUploaded: false})
      )

