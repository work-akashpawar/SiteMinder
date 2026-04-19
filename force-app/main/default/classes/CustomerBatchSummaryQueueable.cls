/**
 * Name         :   Akash Pawar
 * Description  :   Queueable class to send summary email after batch processing Chained from
 *                  CustomerBatchProcessor to provide post-processing
 * Features:
 * - Sends HTML formatted email with processing summary
 * - Includes batch job statistics
 * - Lists failed record IDs
 * - Can be chained with additional queueable jobs if needed
 */
public class CustomerBatchSummaryQueueable implements Queueable {
    
    private String recipientEmail;
    private Integer totalProcessed;
    private Integer totalSucceeded;
    private Integer totalFailed;
    private List<String> failedRecordIds;
    private AsyncApexJob batchJob;
    
    /**
     * Constructor
     * @param email Recipient email address
     * @param processed Total records processed
     * @param succeeded Total records successfully processed
     * @param failed Total records that failed
     * @param failedIds List of failed record IDs
     * @param job Batch job details
     */
    public CustomerBatchSummaryQueueable(
        String email,
        Integer processed,
        Integer succeeded,
        Integer failed,
        List<String> failedIds,
        AsyncApexJob job
    ) {
        this.recipientEmail = email;
        this.totalProcessed = processed;
        this.totalSucceeded = succeeded;
        this.totalFailed = failed;
        this.failedRecordIds = failedIds != null ? failedIds : new List<String>();
        this.batchJob = job;
    }
    
    /**
     * Execute method - Send summary email
     * @param context Queueable context
     */
    public void execute(QueueableContext context) {
        try {
            // Send summary email
            sendSummaryEmail();
            
            // Log completion
            System.debug('Summary email sent successfully to: ' + recipientEmail);
            
        } catch (Exception e) {
            // Log error if email fails
            ErrorLogService.logError(
                'CustomerBatchSummaryQueueable',
                'Failed to send summary email: ' + e.getMessage(),
                null,
                e.getStackTraceString(),
                'Medium'
            );
        }
    }
    
    /**
     * Sends HTML formatted summary email
     */
    private void sendSummaryEmail() {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        
        // Set recipient
        email.setToAddresses(new List<String>{ recipientEmail });
        
        // Set subject
        email.setSubject('Customer Batch Processing Summary - ' + 
                        Datetime.now().format('yyyy-MM-dd HH:mm'));
        
        // Build HTML email body
        String htmlBody = buildHtmlEmailBody();
        email.setHtmlBody(htmlBody);
        
        // Set plain text version
        String plainBody = buildPlainTextBody();
        email.setPlainTextBody(plainBody);
        
        // Send email
        Messaging.SendEmailResult[] results = Messaging.sendEmail(
            new List<Messaging.SingleEmailMessage>{ email }
        );
        
        // Check if email was sent successfully
        if (!results[0].isSuccess()) {
            throw new EmailException('Failed to send email: ' + 
                                   results[0].getErrors()[0].getMessage());
        }
    }
    
    /**
     * Builds HTML formatted email body
     * @return HTML string
     */
    private String buildHtmlEmailBody() {
        Decimal successRate = totalProcessed > 0 ? 
            (Decimal.valueOf(totalSucceeded) / Decimal.valueOf(totalProcessed) * 100).setScale(2) : 0;
        
        String statusColor = totalFailed == 0 ? '#28a745' : (totalFailed > totalSucceeded ? '#dc3545' : '#ffc107');
        
        String html = '<html><head><style>' +
            'body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }' +
            '.container { max-width: 600px; margin: 0 auto; padding: 20px; }' +
            '.header { background-color: #0070d2; color: white; padding: 20px; border-radius: 5px 5px 0 0; }' +
            '.content { background-color: #f4f6f9; padding: 20px; }' +
            '.summary-box { background-color: white; padding: 15px; margin: 10px 0; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }' +
            '.stat { display: inline-block; margin: 10px 20px 10px 0; }' +
            '.stat-label { font-size: 12px; color: #666; }' +
            '.stat-value { font-size: 24px; font-weight: bold; color: ' + statusColor + '; }' +
            '.success { color: #28a745; }' +
            '.failed { color: #dc3545; }' +
            '.warning { color: #ffc107; }' +
            '.footer { background-color: #f4f6f9; padding: 15px; text-align: center; font-size: 12px; color: #666; border-radius: 0 0 5px 5px; }' +
            'table { width: 100%; border-collapse: collapse; margin: 10px 0; }' +
            'th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }' +
            'th { background-color: #0070d2; color: white; }' +
            '</style></head><body>' +
            '<div class="container">' +
            '<div class="header">' +
            '<h2>Customer Batch Processing Report</h2>' +
            '<p>Processing completed at ' + Datetime.now().format('EEEE, MMMM d, yyyy \'at\' h:mm a') + '</p>' +
            '</div>' +
            '<div class="content">';
        
        // Summary statistics
        html += '<div class="summary-box">' +
            '<h3>Processing Summary</h3>' +
            '<div class="stat">' +
            '<div class="stat-label">Total Processed</div>' +
            '<div class="stat-value">' + totalProcessed + '</div>' +
            '</div>' +
            '<div class="stat">' +
            '<div class="stat-label">Succeeded</div>' +
            '<div class="stat-value success">' + totalSucceeded + '</div>' +
            '</div>' +
            '<div class="stat">' +
            '<div class="stat-label">Failed</div>' +
            '<div class="stat-value failed">' + totalFailed + '</div>' +
            '</div>' +
            '<div class="stat">' +
            '<div class="stat-label">Success Rate</div>' +
            '<div class="stat-value">' + successRate + '%</div>' +
            '</div>' +
            '</div>';
        
        // Batch job details
        if (batchJob != null) {
            html += '<div class="summary-box">' +
                '<h3>Batch Job Details</h3>' +
                '<table>' +
                '<tr><th>Property</th><th>Value</th></tr>' +
                '<tr><td>Job ID</td><td>' + batchJob.Id + '</td></tr>' +
                '<tr><td>Status</td><td>' + batchJob.Status + '</td></tr>' +
                '<tr><td>Batches Processed</td><td>' + batchJob.JobItemsProcessed + ' / ' + batchJob.TotalJobItems + '</td></tr>' +
                '<tr><td>Started</td><td>' + batchJob.CreatedDate.format() + '</td></tr>' +
                '<tr><td>Completed</td><td>' + (batchJob.CompletedDate != null ? batchJob.CompletedDate.format() : 'N/A') + '</td></tr>' +
                '</table>' +
                '</div>';
        }
        
        // Failed records
        if (!failedRecordIds.isEmpty()) {
            html += '<div class="summary-box">' +
                '<h3 class="failed">Failed Records (' + failedRecordIds.size() + ')</h3>' +
                '<p>The following customer records failed processing:</p>' +
                '<ul>';
            
            Integer displayLimit = Math.min(failedRecordIds.size(), 20);
            for (Integer i = 0; i < displayLimit; i++) {
                html += '<li><a href="' + URL.getSalesforceBaseUrl().toExternalForm() + '/' + 
                       failedRecordIds[i] + '">' + failedRecordIds[i] + '</a></li>';
            }
            
            if (failedRecordIds.size() > 20) {
                html += '<li><em>... and ' + (failedRecordIds.size() - 20) + ' more</em></li>';
            }
            
            html += '</ul>' +
                '<p><strong>Action Required:</strong> Review error logs for detailed information.</p>' +
                '</div>';
        } else {
            html += '<div class="summary-box">' +
                '<h3 class="success">✓ All Records Processed Successfully</h3>' +
                '<p>No errors were encountered during batch processing.</p>' +
                '</div>';
        }
        
        html += '</div>' +
            '<div class="footer">' +
            '<p>This is an automated email from Salesforce Customer Batch Processor.</p>' +
            '<p>To view error logs, navigate to Error Log object in Salesforce.</p>' +
            '</div>' +
            '</div>' +
            '</body></html>';
        
        return html;
    }
    
    /**
     * Builds plain text email body
     * @return Plain text string
     */
    private String buildPlainTextBody() {
        String text = 'CUSTOMER BATCH PROCESSING REPORT\n';
        text += '================================\n\n';
        text += 'Processing completed at: ' + Datetime.now().format('yyyy-MM-dd HH:mm:ss') + '\n\n';
        
        text += 'SUMMARY:\n';
        text += '--------\n';
        text += 'Total Processed: ' + totalProcessed + '\n';
        text += 'Succeeded: ' + totalSucceeded + '\n';
        text += 'Failed: ' + totalFailed + '\n';
        
        Decimal successRate = totalProcessed > 0 ? 
            (Decimal.valueOf(totalSucceeded) / Decimal.valueOf(totalProcessed) * 100).setScale(2) : 0;
        text += 'Success Rate: ' + successRate + '%\n\n';
        
        if (batchJob != null) {
            text += 'BATCH JOB DETAILS:\n';
            text += '------------------\n';
            text += 'Job ID: ' + batchJob.Id + '\n';
            text += 'Status: ' + batchJob.Status + '\n';
            text += 'Batches: ' + batchJob.JobItemsProcessed + ' / ' + batchJob.TotalJobItems + '\n\n';
        }
        
        if (!failedRecordIds.isEmpty()) {
            text += 'FAILED RECORDS (' + failedRecordIds.size() + '):\n';
            text += '-------------------\n';
            
            Integer displayLimit = Math.min(failedRecordIds.size(), 20);
            for (Integer i = 0; i < displayLimit; i++) {
                text += '- ' + failedRecordIds[i] + '\n';
            }
            
            if (failedRecordIds.size() > 20) {
                text += '... and ' + (failedRecordIds.size() - 20) + ' more\n';
            }
            
            text += '\nPlease review error logs for detailed information.\n';
        } else {
            text += 'All records processed successfully!\n';
        }
        
        text += '\n---\n';
        text += 'This is an automated email from Salesforce Customer Batch Processor.\n';
        
        return text;
    }
    
    /**
     * Custom exception for email failures
     */
    public class EmailException extends Exception {}
}