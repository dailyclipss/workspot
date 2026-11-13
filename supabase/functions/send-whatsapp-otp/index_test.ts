import { unsupportedOtpVersionResponse } from '../_shared/otp.ts';

Deno.test('non-v2 OTP requests receive an update-required response', async () => {
  for (const version of [undefined, 1, '2']) {
    const response = unsupportedOtpVersionResponse(version);
    if (!response || response.status !== 426) {
      throw new Error(`Expected version ${String(version)} to be rejected with 426.`);
    }

    const body = await response.json();
    if (body.error !== 'Please update the WorkSpot app to send an OTP.') {
      throw new Error('Expected the response to tell the app to update.');
    }
  }
});

Deno.test('v2 OTP requests continue to the current flow', () => {
  if (unsupportedOtpVersionResponse(2) !== null) {
    throw new Error('Expected v2 to pass the version check.');
  }
});
