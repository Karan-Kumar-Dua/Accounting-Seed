import { LightningElement } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import staticResource from '@salesforce/resourceUrl/accounting_resources';
import Labels from './labels';
import { LabelService } from "c/utils";

/**
 * Displays a card containing links to Accounting Seed University
 * and the knowledge base.
 */
export default class UniversityCard extends LightningElement {
    labels = {...LabelService, ...Labels};

    /**
     * Loads IBM Plex Sans font.
     */
    connectedCallback () {
        loadStyle(this, staticResource + '/css/accounting.css');  
    }

}