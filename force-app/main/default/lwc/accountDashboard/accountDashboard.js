import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { updateRecord } from 'lightning/uiRecordApi';
import getAccountData from '@salesforce/apex/AccountDashboardController.getAccountData';
import ID_FIELD from '@salesforce/schema/Contact.Id';
import PHONE_FIELD from '@salesforce/schema/Contact.Phone';
import EMAIL_FIELD from '@salesforce/schema/Contact.Email';

export default class AccountDashboard extends LightningElement {
    @api recordId; // Account Id from record page
    @track contacts = [];
    @track opportunities = [];
    @track filteredOpportunities = [];
    @track stageFilter = '';
    @track isLoading = false;
    @track error;
    @track draftValues = [];
    
    accountName = '';
    wiredAccountDataResult;

    // Define columns for Contact datatable with inline editing
    contactColumns = [
        { label: 'Name', fieldName: 'Name', type: 'text', editable: false },
        { label: 'Email', fieldName: 'Email', type: 'email', editable: true },
        { label: 'Phone', fieldName: 'Phone', type: 'phone', editable: true },
        { label: 'Title', fieldName: 'Title', type: 'text', editable: false }
    ];

    // Define columns for Opportunity datatable
    opportunityColumns = [
        { label: 'Name', fieldName: 'Name', type: 'text' },
        { label: 'Stage', fieldName: 'StageName', type: 'text' },
        { label: 'Amount', fieldName: 'Amount', type: 'currency', typeAttributes: { currencyCode: 'USD' }},
        { label: 'Close Date', fieldName: 'CloseDate', type: 'date' }
    ];

    // Wire service to fetch Account data with related Contacts and Opportunities
    @wire(getAccountData, { accountId: '$recordId' })
    wiredAccountData(result) {
        this.wiredAccountDataResult = result;
        const { data, error } = result;
        
        this.isLoading = true;
        
        if (data) {
            this.accountName = data.accountName || '';
            this.contacts = data.contacts || [];
            this.opportunities = data.opportunities || [];
            this.filteredOpportunities = [...this.opportunities];
            this.error = undefined;
            this.isLoading = false;
        } else if (error) {
            this.handleError(error);
            this.isLoading = false;
        }
    }

    // Handle stage filter input change
    handleStageFilterChange(event) {
        this.stageFilter = event.target.value.toLowerCase().trim();
        this.filterOpportunities();
    }

    // Filter opportunities by stage without page reload
    filterOpportunities() {
        if (!this.stageFilter) {
            this.filteredOpportunities = [...this.opportunities];
        } else {
            this.filteredOpportunities = this.opportunities.filter(opp => 
                opp.StageName && opp.StageName.toLowerCase().includes(this.stageFilter)
            );
        }
    }

    // Handle inline edit save for Contacts
    async handleContactSave(event) {
        const draftValues = event.detail.draftValues;
        this.isLoading = true;

        try {
            // Prepare records for update
            const recordsToUpdate = draftValues.map(draft => {
                const fields = { 
                    [ID_FIELD.fieldApiName]: draft.Id 
                };
                
                // Only include fields that were actually edited
                if (draft.Email !== undefined) {
                    fields[EMAIL_FIELD.fieldApiName] = draft.Email;
                }
                if (draft.Phone !== undefined) {
                    fields[PHONE_FIELD.fieldApiName] = draft.Phone;
                }
                
                return { fields };
            });

            // Update all records using Lightning Data Service
            const updatePromises = recordsToUpdate.map(recordInput => 
                updateRecord(recordInput)
            );
            
            await Promise.all(updatePromises);

            // Show success message
            this.showToast('Success', 'Contacts updated successfully', 'success');

            // Clear draft values in datatable
            //this.template.querySelector('lightning-datatable[data-id="contactTable"]').draftValues = [];
            this.draftValues = [];

            // Refresh the data from server
            await refreshApex(this.wiredAccountDataResult);

        } catch (error) {
            this.handleError(error);
        } finally {
            this.isLoading = false;
        }
    }

    // Handle errors consistently
    handleError(error) {
        let message = 'Unknown error';
        
        if (error) {
            if (error.body) {
                if (error.body.message) {
                    message = error.body.message;
                } else if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                    message = error.body.pageErrors[0].message;
                } else if (error.body.fieldErrors) {
                    const fieldErrorMessages = [];
                    Object.values(error.body.fieldErrors).forEach(fieldError => {
                        fieldError.forEach(err => fieldErrorMessages.push(err.message));
                    });
                    message = fieldErrorMessages.join(', ');
                }
            } else if (error.message) {
                message = error.message;
            } else if (typeof error === 'string') {
                message = error;
            }
        }
        
        this.error = message;
        this.showToast('Error', message, 'error');
    }

    // Show toast notification
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    // Computed properties for conditional rendering
    get hasContacts() {
        return this.contacts && this.contacts.length > 0;
    }

    get hasOpportunities() {
        return this.filteredOpportunities && this.filteredOpportunities.length > 0;
    }

    get noContactsMessage() {
        return 'No contacts found for this account.';
    }

    get noOpportunitiesMessage() {
        return this.stageFilter 
            ? `No opportunities found matching stage: "${this.stageFilter}"`
            : 'No opportunities found for this account.';
    }

    get opportunityCountMessage() {
        const total = this.opportunities.length;
        const filtered = this.filteredOpportunities.length;
        
        if (this.stageFilter && filtered < total) {
            return `Showing ${filtered} of ${total} opportunities`;
        }
        return `Total: ${total} opportunities`;
    }
}