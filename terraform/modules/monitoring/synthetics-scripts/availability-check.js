const synthetics = require('Synthetics');
const log = require('SyntheticsLogger');

const apiCanaryBlueprint = async function () {
    const targetUrl = process.env.TARGET_URL || '${target_url}';
    
    const requestOptionsStep1 = {
        hostname: new URL(targetUrl).hostname,
        method: 'GET',
        path: '/health',
        port: 443,
        protocol: 'https:',
        headers: {
            'User-Agent': 'CloudWatch-Synthetics-Canary'
        }
    };
    
    // Health check endpoint
    await synthetics.executeStep('healthCheck', async function () {
        const response = await synthetics.executeHttpStep(requestOptionsStep1);
        return response;
    });

    // Application root endpoint
    const requestOptionsStep2 = {
        ...requestOptionsStep1,
        path: '/'
    };
    
    await synthetics.executeStep('rootEndpoint', async function () {
        const response = await synthetics.executeHttpStep(requestOptionsStep2);
        return response;
    });
};

exports.handler = async () => {
    return await synthetics.executeStep('canary', apiCanaryBlueprint);
};
