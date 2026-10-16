import { NextResponse } from 'next/server';
import crypto from 'crypto';

export async function POST(req: Request) {
  try {
    const formData = await req.formData();
    const dataBase64 = formData.get('data') as string;
    const receivedSign = formData.get('sign') as string;

    const privateKey = process.env.EPOINT_PRIVATE_KEY;

    if (!dataBase64 || !receivedSign || !privateKey) {
      return NextResponse.json({ error: 'Çatışmayan parametr' }, { status: 400 });
    }

    // İmzalanmanın doğrulanması
    const expectedSignature = crypto
      .createHash('sha1')
      .update(privateKey + dataBase64 + privateKey)
      .digest('base64');

    if (expectedSignature !== receivedSign) {
      return NextResponse.json({ error: 'Yanlış imza (Invalid signature)' }, { status: 400 });
    }

    const decodedData = JSON.parse(Buffer.from(dataBase64, 'base64').toString('utf-8'));

    if (decodedData.status === 'success') {
      // Burada verilənlər bazasında ödəniş statusunu yenilə (məs. Supabase/PostgreSQL)
      console.log('Ödəniş uğurla tamamlandı:', decodedData);
    }

    return NextResponse.json({ status: 'ok' });
  } catch (error: any) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}
