import {LightningElement} from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import staticResource from '@salesforce/resourceUrl/accounting_resources';

export default class AccountingHome extends LightningElement {

    connectedCallback() {
        loadStyle(this, staticResource + '/css/accounting.css');
    }

}