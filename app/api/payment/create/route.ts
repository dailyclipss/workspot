import { NextResponse } from 'next/server';
import crypto from 'crypto';

export async function POST(req: Request) {
  try {
    const { amount, description, orderId } = await req.json();

    const publicKey = process.env.EPOINT_PUBLIC_KEY;
    const privateKey = process.env.EPOINT_PRIVATE_KEY;

    if (!publicKey || !privateKey) {
      return NextResponse.json({ error: 'API açarları tapılmadı' }, { status: 500 });
    }

    const data = {
      public_key: publicKey,
      amount: amount || "1.00",
      currency: "AZN",
      language: "az",
      order_id: orderId || `order_${Date.now()}`,
      description: description || "Workspot ödənişi",
      success_redirect_url: "https://workspot.az/payment/success",
      error_redirect_url: "https://workspot.az/payment/error"
    };

    const dataString = JSON.stringify(data);
    const dataBase64 = Buffer.from(dataString).toString('base64');

    const signatureString = privateKey + dataBase64 + privateKey;
    const signature = crypto.createHash('sha1').update(signatureString).digest('base64');

    const params = new URLSearchParams();
    params.append('data', dataBase64);
    params.append('sign', signature);

    const response = await fetch('https://epoint.az/api/1/request', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: params.toString(),
    });

    const result = await response.json();

    if (result.status === 'success' && result.redirect_url) {
      return NextResponse.json({ url: result.redirect_url });
    } else {
      return NextResponse.json({ error: result.message || 'Ödəniş yaradılmadı' }, { status: 400 });
    }
  } catch (error: any) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}
