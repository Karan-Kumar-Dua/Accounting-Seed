import {LightningElement, api, track} from 'lwc';
import { LabelService } from "c/utils";
import Labels from './labels';

export default class CommentsHandler extends LightningElement {

    labels = {...LabelService, ...Labels};
    //public properties =======================================
    @api internalComment;
    @api invoiceComment;
    @api isInternalCommentAccessible = false;
    @api isInternalCommentUpdateable = false;
    @api isInvoiceCommentAccessible = false;
    @api isInvoiceCommentUpdateable = false;
    @api editMode = false;

    //private reactive properties =============================
    @track showAddCommentDialog = false;
    @track showComments = false;
    //private properties ======================================
    tempInternalComment;
    tempInvoiceComment;
    //getters =================================================
    get hasComments() {
        return (
            (this.internalComment !== undefined && this.internalComment !== null)
                || (this.invoiceComment !== undefined && this.invoiceComment !== null)
        );
    }

    get buttonTitle() {
        return this.editMode ? Labels.INF_ADD_COMMENTS : Labels.INF_VIEW_COMMENTS;
    }

    get iconName() {
        if (this.hasComments) {
            return "/_slds/icons/standard-sprite/svg/symbols.svg#product_required";
        }
            return "/_slds/icons/standard-sprite/svg/symbols.svg#product_request";
        }

    get className() {
        if (this.hasComments) {
            return "slds-button__icon slds-m-left_xx-small slds-button__icon_large has-comments";
        }
            return "slds-button__icon slds-m-left_xx-small slds-button__icon_large no-comments";
        }

    get isCommentsNotAccessible() {
        return !this.isInternalCommentAccessible && !this.isInvoiceCommentAccessible;
    }

    get isCommentsNotUpdateable() {
        return !this.isInternalCommentUpdateable && !this.isInvoiceCommentUpdateable;
    }

    //event handlers =============================================
    handleCloseDialog() {
        this.showAddCommentDialog = false;
        this.showComments = false;
    }

    handleOpenDialog() {
        if (this.editMode) {
            this.tempInternalComment = this.internalComment;
            this.tempInvoiceComment = this.invoiceComment;
            this.showAddCommentDialog = true;
        }
        else {
            this.showComments = true;
        }

    }

    handleInternalCommentChange(event) {
        this.tempInternalComment = this.isNonWhiteSpaceComment(event.target.value) ? event.target.value : null;
    }

    handleInvoiceCommentChange(event) {
        this.tempInvoiceComment = this.isNonWhiteSpaceComment(event.target.value) ? event.target.value : null;
    }
    isNonWhiteSpaceComment = (comment) => comment.match(/^ *$/) == null ;

    handleAddComments() {
        if (this.internalComment !== this.tempInternalComment
                || this.invoiceComment !== this.tempInvoiceComment) {

            const event = CustomEvent('commentschange', {
                detail: {
                    internalComment: this.tempInternalComment,
                    invoiceComment: this.tempInvoiceComment
                }
            });
            this.dispatchEvent(event);
        }

        this.showAddCommentDialog = false;
    }

}