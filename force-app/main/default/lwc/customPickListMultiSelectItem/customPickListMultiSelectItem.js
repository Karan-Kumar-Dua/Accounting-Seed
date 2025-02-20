import { LightningElement, api } from "lwc";
import Labels from "./labels";

export default class CustomPickListMultiSelectItem extends LightningElement {
  @api key = '';
  @api value = '';
  @api label = '';
  @api selected = false;
  labels = Labels;

  get listItemStyle() {
    var baseStyles = ' slds-media  slds-listbox__option_plain slds-media_small slds-listbox__option ';
    return this.selected === true ? baseStyles + ' slds-is-selected ' : baseStyles ;
  }

  selectHandler(event) {
    // Prevents the anchor element from navigating to a URL.
    event.preventDefault();
    event.stopPropagation();
    const selectedEvent = new CustomEvent('selected', { detail: {label:this.label,value:this.value,selected:this.selected,shift:event.shiftKey} });
    this.dispatchEvent(selectedEvent);
  }
}