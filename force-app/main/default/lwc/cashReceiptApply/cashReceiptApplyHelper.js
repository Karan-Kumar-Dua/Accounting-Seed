import { LabelService } from "c/utils";
import Labels from "./labels";

export default class Helper {
    
    // ==================
    // Public
    // ==================

    static validateInvoice(invoice, cashReceipt) {
        const validationPipeline = [
            Helper._validateAdjustmentGL(invoice),
            Helper._validateAppliedAmountPositive(invoice),
            Helper._validateInvoiceNotOverapplied(invoice),
            Helper._validateCasheReceiptNotOverapplied(invoice, cashReceipt)
        ];

        const errors = validationPipeline.reduce(Helper._validationReducer, []);
        
        return {
            ok: errors.length === 0,
            errors: errors
        };
    }

    static getDiscountAmount(invoice, cashReceipt) {
        if (!Helper._isEligibleForAutoCalculatedDiscount(invoice, cashReceipt)) {
            return 0;
        } else if (invoice.balance < invoice.discountAmount) {
            return invoice.balance;
        }
            return invoice.discountAmount;
        }

    // ==================
    // Private
    // ==================

    // Discount Calculation

    static _isEligibleForAutoCalculatedDiscount (invoice, cashReceipt) {
        const eligibilityPipeline = [
            Helper._hasDiscount(invoice),
            Helper._hasValidDiscount(invoice, cashReceipt),
            Helper._hasNoAdjustmet(invoice),
            Helper._hasNoBCMAdjustment(invoice),
            Helper._hasNoOtherBCRAdjustment(invoice)
        ];

        return eligibilityPipeline.reduce(Helper._eligibilityReducer, true);
    }
    
    static _eligibilityReducer = (eligible, rule) => rule() && eligible;

    static _hasDiscount = invoice => () => Boolean(invoice.discountDueDate && invoice.discountAmount);
    static _hasValidDiscount = (invoice, cashReceipt) => () => cashReceipt.receiptDate <= invoice.discountDueDate;
    static _hasNoAdjustmet = invoice => () => invoice.adjustmentAmount === 0;
    static _hasNoBCMAdjustment = invoice => () => invoice.creditMemoAppliedAmount === 0;
    static _hasNoOtherBCRAdjustment = invoice => () => invoice.cashApplicationAdjustmentAmount - invoice.initialAdjustmentAmount === 0;

    // Validations

    static validationMsgs = {
        OVERAPPLIED_INVOICE: LabelService.errorBillingBalanceNotLessThanZero,
        OVERAPPLIED_CREDIT: Labels.ERR_CR_BALANCE_CANNOT_LESS_THAN_0,
        APPLIED_AMOUNT_LESS_THAN_ZERO: Labels.ERR_RECIEVED_AMT_CANNOT_LESS_THAN_0,
        ADJUSTMENT_AMOUNT_LESS_THAN_ZERO: Labels.ERR_ADJUSTMENT_AMT_CANNOT_LESS_THAN_0,
        ADJUSTMENT_GL_ACCOUNT_REQUIRED: Labels.ERR_ADJUSTMENT_GL_ACCT_REQ
    }

    static _validationReducer = (errors, rule) => {
        const { ok, error } = rule();
        if (!ok) {
            errors.push(error);
        } 
        return errors;
    }

    static _validateAdjustmentGL = invoice => () => {
        const ok = Boolean(invoice.adjustmentAmount === 0 || ((invoice.adjustmentAmount !== 0) && invoice.glAccount));
        return {
            ok: ok,
            error: ok ? undefined : { field: 'adjustmentAmount', msg: Helper.validationMsgs.ADJUSTMENT_GL_ACCOUNT_REQUIRED }
        };
    }

    static _validateAppliedAmountPositive = invoice => () => {
        const ok = invoice.appliedAmount >= 0;
        return {
            ok: ok,
            error: ok ? undefined : { field: 'appliedAmount', msg:  Helper.validationMsgs.APPLIED_AMOUNT_LESS_THAN_ZERO }
        };
    }

    static _validateInvoiceNotOverapplied = invoice => () => {
        const ok = invoice.balance >= 0;
        return { 
            ok: ok,
            error: ok ? undefined : { 
                field: invoice.adjustmentAmount > 0 ? 'adjustmentAmount' : 'appliedAmount', 
                msg:  Helper.validationMsgs.OVERAPPLIED_INVOICE 
            }
        };
    }

    static _validateCasheReceiptNotOverapplied = (invoice, cashReceipt) => () => {
        const ok = cashReceipt.balance >= 0;
        return { 
            ok: ok,
            error: ok ? undefined : { 
                field: invoice.adjustmentAmount > 0 ? 'adjustmentAmount' : 'appliedAmount', 
                msg:  Helper.validationMsgs.OVERAPPLIED_CREDIT 
            }
        };
    }
};