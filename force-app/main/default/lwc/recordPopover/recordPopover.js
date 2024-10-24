import { wire, track, api } from 'lwc';
import { NavigationService, CommonUtils, LabelService } from 'c/utils';
import { getRecord } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';

const LEFT_HORIZONTAL_ARRANGEMENT = 'left';
const RIGHT_HORIZONTAL_ARRANGEMENT = 'right';

const CLASSES_BY_HORIZONTAL_ARRANGEMENT = {
    [LEFT_HORIZONTAL_ARRANGEMENT]: ['slds-nubbin_right-top', 'recordPopover--leftArrangement'],
    [RIGHT_HORIZONTAL_ARRANGEMENT]: ['slds-nubbin_left-top']
};

/**
 * Display a popover containing a record-view-form when the child
 * element of this component is hovered over. Child element is
 * displayed within a slot, and the popover is positioned
 * to the right of that slot container.
 */
export default class RecordPopover extends NavigationService {

    labels = LabelService;
    /**
     * For display purposes: output a link with the record name
     */
    @wire(getRecord, { recordId: '$recordId', fields: '$_fields' })
    record;

    @wire(getObjectInfo, { objectApiName: '$objectApiName'})
    objectInfo;

    @api recordId;

    @api objectApiName;

    @api horizontalArrangement = RIGHT_HORIZONTAL_ARRANGEMENT;

    /**
     * An array of field API names
     */
    @api fields;

    /**
     * Customize the title, otherwise the object display
     * name will be used.
     */
    @api title;

    /**
     * Internal only; updates with field name format
     * once `objectApiName` is poulated
     */
    @track _fields;

    _url = '#';

    get url () {
        if (this.recordId) {
            this.getNavigationUrl(this.recordId).then(url => this._url = url);
        }
        return this._url;
    }

    /**
     * Popover visibility
     */
    isVisible = false;

    /**
     * Entire component visibility
     */
    get hasRecord () {
        return this.recordId && this.fields
    }

    /**
     * Adds visibility classes
     */
    get popoverClasses () {
        return CommonUtils.computeClasses([
            'slds-popover',
            'slds-popover_walkthrough',
            'recordPopover',
            !this.isVisible && 'slds-hidden',
            ...CLASSES_BY_HORIZONTAL_ARRANGEMENT[this.horizontalArrangement]
        ]);
    }

    get hasObjectTitle () {
        return this.objectInfo && this.objectInfo.data && !this.title;
    }

    /**
     * Smart aria
     */
    get ariaDescribedBy () {
        return `dialog-body-${this.recordId}`;
    }

    get ariaLabeledBy () {
        return `dialog-heading-${this.recordId}`;
    }

    /**
     * Manual methods to show/hide
     */
    @api show () {
        this.isVisible = true;
    }

    @api hide () {
        this.isVisible = false;
    }

    /**
     * Display popover on hover
     */
    handleMouseover () {
        this.isVisible = true;
    }

    /**
     * Hide popover when not hovered
     */
    handleMouseout () {
        this.isVisible = false;
    }

    /**
     * Redirect to record page
     */
    handleView () {
        this.navigateToViewRecordPage(this.recordId);
    }

    /**
     * Open edit modal
     */
    handleEdit () {
        this.navigateToEditRecordPage(this.recordId);
    }

    /**
     * Lifecycle events
     */
    connectedCallback () {
        // Can't build the correct format until
        // `this` context is established
        this._fields = [
            `${this.objectApiName}.Name`
        ];
    }

}