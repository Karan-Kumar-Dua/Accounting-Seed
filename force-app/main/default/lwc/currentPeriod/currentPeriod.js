import { LightningElement, wire } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import staticResource from '@salesforce/resourceUrl/accounting_resources';
import getCurrentPeriod from '@salesforce/apex/AccountingHomeHelper.getCurrentPeriod';
import Labels from './labels';

export default class CurrentPeriod extends LightningElement {

    @wire (getCurrentPeriod)
    currentPeriod;

    labels = Labels;
    
    get hasCurrentPeriod() {
        return this.currentPeriod && this.currentPeriod.data;
    }

    connectedCallback () {
        loadStyle(this, staticResource + '/css/accounting.css');  
    }

}