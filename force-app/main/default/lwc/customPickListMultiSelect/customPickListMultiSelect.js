import { LightningElement, api, track } from "lwc";
import { LabelService } from "c/utils";
import Labels from "./labels";

export default class CustomPickListMultiSelect extends LightningElement {
  @api width = 100;
  @api variant = '';
  @api label = '';
  @api dropdownLength = 5;
  @api options = [{label:LabelService.commonNone,value:'None',selected:false},];
  @track _options = [];
  @track isOpen = false;
  @api selectedPills = [];
  @track _selectedPills = [];
  labels = LabelService;

  @api
  selectedValues(){
    var values = []
    this._options.forEach(function(option) {
      if (option.selected === true) {
        values.push(option.value);
      }
    });
    return values;
  }
  @api
  selectedObjects(){
    var values = []
    this._options.forEach(function(option) {
      if (option.selected === true) {
        values.push(option);
      }
    });
    return values;
  }
  @api
  value(){
    return this.selectedValues().join(';')
  }


  connectedCallback() {
    //copy public attributes to private ones
    this._options = JSON.parse(JSON.stringify(this.options));
    this._selectedPills = JSON.parse(JSON.stringify(this.selectedPills));
  }

  get labelStyle() {
    return this.variant === 'label-hidden' ? ' slds-hide' : ' slds-form-element__label ' ;
  }

  get dropdownOuterStyle(){
    return 'slds-dropdown slds-dropdown_fluid slds-dropdown_length-5' + this.dropdownLength;
  }

  get mainDivClass(){
    var style = ' slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ';
    return this.isOpen ? ' slds-is-open ' + style : style;
  }
  get hintText(){
    if (this._selectedPills.length === 0) {
      return Labels.INF_SELECT_AN_OPTION;
    }
    return "";
  }

  openDropdown(){
    this.isOpen = true;
  }
  closeDropdown(){
    this.isOpen = false;
  }

  handleClick(event){
    event.stopImmediatePropagation();
    this.openDropdown();
    document.addEventListener('click', this.handleClose);
  }
  handleClose = (event) => {
    event.stopPropagation();
    this.closeDropdown();
    document.removeEventListener('click', this.handleClose);
  }

  handlePillRemove(event){
    event.preventDefault();
    event.stopPropagation();

    const name = event.detail.item.name;
    //const index = event.detail.index;

    this._options.forEach(function(element) {
      if (element.value === name) {
        element.selected = false;
      }
    });
    this._selectedPills = this.getPillArray();
    this.despatchChangeEvent();

  }

  despatchChangeEvent() {
    const eventDetail = {value:this.value(),selectedItems:this.selectedObjects()};
    const changeEvent = new CustomEvent('change', {composed: true, bubbles: true, detail: eventDetail });
    this.dispatchEvent(changeEvent);
  }

  handleSelectedClick(event){

    var value;
    var selected;
    event.preventDefault();
    event.stopPropagation();

    const listData = event.detail;

    value = listData.value;
    selected = listData.selected;

    //shift key ADDS to the list (unless clicking on a previously selected item)
    //also, shift key does not close the dropdown.
    if (listData.shift) {
      this._options.forEach(function(option) {
        if (option.value === value) {
          option.selected = selected === true ? false : true;
        }
      });
    }
    else {
      this._options.forEach(function(option) {
        if (option.value === value) {
          option.selected = selected === "true" ? false : true;
        } else {
          option.selected = false;
        }
      });
      this.closeDropdown();
    }

    this._selectedPills = this.getPillArray();
    this.despatchChangeEvent();

  }

  getPillArray(){
    var pills = [];
    this._options.forEach(function(element) {
      var interator = 0;
      if (element.selected) {
        pills.push({label:element.label, name:element.value, key: interator++});
      }
    });
    return pills;
  }

}