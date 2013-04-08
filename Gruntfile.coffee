module.exports = (grunt) ->

  grunt.initConfig

    pkg: grunt.file.readJSON 'package.json'

    meta:
      banner: '// <%= pkg.name %> v<%= pkg.version %> - by Alvaro Prieto Lauroba - MIT & GPL\n'
      large: '''
/**
               _ _____           _          _     _
              | |  __ \\         (_)        | |   | |
      ___ ___ | | |__) |___  ___ _ ______ _| |__ | | ___
     / __/ _ \\| |  _  // _ \\/ __| |_  / _` | '_ \\| |/ _ \\
    | (_| (_) | | | \\ \\  __/\\__ \\ |/ / (_| | |_) | |  __/
     \\___\\___/|_|_|  \\_\\___||___/_/___\\__,_|_.__/|_|\\___|

  v<%= pkg.version %> - a jQuery plugin by Alvaro Prieto Lauroba

  Licences: MIT & GPL
  Feel free to use or modify this plugin as far as my full name is kept

  If you are going to use this plugin in production environments it is
  strongly recomended to use its minified version: <%= pkg.name %>.min.js

*/
      '''

    clean:
      build: ['build/']

    watch:
      scripts:
        files: ['source/colResizable.coffee']
        tasks: ['coffee', 'coffeelint']

    coffee:
      options:
        bare: true
      compile:
        files:
          'build/colResizable.js': 'source/colResizable.coffee'

    uglify:
      options:
        banner: '<%= meta.banner %>'
      all:
        files:
          'colResizable.min.js': ['build/colResizable.js']

    coffeelint:
      build:
        files:
          src: ['source/*.coffee']
      options:
        no_tabs:
          level: 'error'
        no_trailing_whitespace:
          level: 'error'
        max_line_length:
          value: 80
          level: 'error'
        camel_case_classes:
          level: 'error'
        indentation:
          value: 2
          level: 'error'
        no_implicit_braces:
          level: 'ignore'
        no_trailing_semicolons:
          level: 'error'
        no_plusplus:
          level: 'ignore'
        no_throwing_strings:
          level: 'error'
        cyclomatic_complexity:
          value: 10
          level: 'ignore'
        no_backticks:
          level: 'error'
        line_endings:
          value: 'unix'
          level: 'error'

    jshint:
      all: ['build/colResizable.js']
      options:
        boss: true
        curly: false
        eqeqeq: true
        immed: false
        latedef: true
        newcap: true
        noarg: true
        sub: true
        undef: true
        eqnull: true
        node: true

        globals:
          document: true
          jQuery: true
          sessionStorage: true
          window: true

  grunt.loadNpmTasks 'grunt-contrib-clean'
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-coffeelint'
  grunt.loadNpmTasks 'grunt-contrib-jshint'
  grunt.loadNpmTasks 'grunt-contrib-uglify'
  grunt.loadNpmTasks 'grunt-contrib-watch'

  # Tasks
  grunt.registerTask 'default', ['coffee', 'coffeelint', 'jshint', 'uglify']
