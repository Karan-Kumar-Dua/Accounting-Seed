import { LightningElement, api, track } from 'lwc';
import { LabelService } from "c/utils";
import Labels from './labels';

export default class CustomToggle extends LightningElement {

    labels = {...LabelService, ...Labels};
    @api toggleInActiveMsg = Labels.INF_NOT_REGISTERED;
    @api toggleActiveMsg = Labels.INF_REGISTERED;
    @api providervalue; /* used to show the value beside toggle button and it will be in object form
                           where value is required key for show toggle value i.e., checked or unchecked 
                           on load of page and label is used to show the name of toggle button*/
    @api initialValue; //make it api so that can be accessible in parent comp
    @api toggleValue;  //make it api so that can be accessible in parent comp
    @api showWarnings = false; // dynamically used to control extra warining message of true else only toggle

    @track toggleOff;
    @track preventRecursion = true;

    warningAlternativeText = Labels.COMMON_WARNING + '!';


    connectedCallback() {
        if (this.providervalue) {
            this.initialValue = this.providervalue.AcctSeed__Is_Active__c;
        }
    }

    renderedCallback() {
        if (this.preventRecursion) {
            let toggleBox = this.template.querySelector('lightning-input[data-id="toggle"]');
            if (this.providervalue) {
                toggleBox.className = this.providervalue.AcctSeed__Is_Active__c ? 'toggleOnClass' : 'toggleOffOnLoadClass';
            }
        }
        this.preventRecursion = false;
    }

    /**
   * description - called when toggle button switches.
   * Params - event
   */
    switchToggle(event) {
        this.toggleOff = !(event.target.checked);
        let toggleBox = this.template.querySelector('lightning-input[data-id="toggle"]');
        toggleBox.className = event.target.checked ? 'toggleOnClass' : 'toggleOffClass';
        this.toggleValue = event.target.checked;
        let detail = {};
        this.fireEvent(detail);
    }

    @api
    queryHTMLElement() {
        return this.template.querySelector('lightning-input[data-id="toggle"]');
    }

    fireEvent(detail) {
        const toggleSwitch = new CustomEvent('toggleswitch', {
            detail,
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(toggleSwitch);
    }

    /**
     * description - used for showing checked or unchecked value of toggle button based on value key of object
     */
    get toggleStatus() {
        return this.providervalue ? this.providervalue.AcctSeed__Is_Active__c : false;
    }
}