import {api, LightningElement} from 'lwc';
import { CommonUtils, LabelService } from "c/utils";

export default class ExpandableSection extends LightningElement {

    @api
    sectionTitle;
    @api
    collapsed = false;
    labels = LabelService;

    get sectionClass() {
        return CommonUtils.computeClasses(['slds-section', !this.collapsed && 'slds-is-open'])
    }

    handleExpando() {
        let sectionDiv = this.template.querySelector('[data-id="expandable-section"]');
        if (sectionDiv) {
            this.collapsed = sectionDiv.className.includes('slds-is-open');
        }
    }

}