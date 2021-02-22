/* eslint no-console:0 */
// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/javascript and only use these pack files to reference
// that code so it'll be compiled.
//
// To reference this file, add <%= javascript_pack_tag 'application' %> to the appropriate
// layout file, like app/views/layouts/application.html.erb


// Uncomment to copy all static images under ../images to the output folder and reference
// them with the image_pack_tag helper in views (e.g <%= image_pack_tag 'rails.png' %>)
// or the `imagePath` JavaScript helper below.
//
// const images = require.context('../images', true)
// const imagePath = (name) => images(name, true)

import 'core-js/stable'
import 'regenerator-runtime/runtime'

import Vue from 'vue/dist/vue.esm'
import Vuex from "vuex"
import system from 'lux-design-system'
import "lux-design-system/dist/system/system.css"
import "lux-design-system/dist/system/tokens/tokens.scss"

import AbsoluteIdForm from '../components/absolute_id_form'
import AbsoluteIdBatchForm from '../components/absolute_id_batch_form'
import AbsoluteIdTable from '../components/absolute_id_table'
import AbsoluteIdBatchTable from '../components/absolute_id_batch_table'
import AbsoluteIdDataList from '../components/absolute_id_data_list'

Vue.use(system)
var elements = document.getElementsByClassName("lux")
for (var i = 0; i < elements.length; i++) {
  new Vue({
    el: elements[i],
    components: {
      'absolute-id-form': AbsoluteIdForm,
      'absolute-id-batch-form': AbsoluteIdBatchForm,
      'absolute-id-batch-table': AbsoluteIdBatchTable,
      'absolute-id-table': AbsoluteIdTable,
      'absolute-id-data-list': AbsoluteIdDataList
    }
  })
}
