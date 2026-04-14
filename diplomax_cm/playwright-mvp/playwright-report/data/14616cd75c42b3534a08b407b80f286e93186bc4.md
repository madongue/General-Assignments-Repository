# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: api.spec.js >> Diplomax Backend MVP >> recruiter login works when credentials are available
- Location: tests\api.spec.js:81:3

# Error details

```
Error: {"detail":"Internal server error"}

expect(received).toContain(expected) // indexOf

Expected value: 500
Received array: [200, 401]
```

# Test source

```ts
  1   | const { test, expect } = require('@playwright/test');
  2   | 
  3   | const studentUser = process.env.STUDENT_USERNAME || 'ICTU20223180';
  4   | const studentPass = process.env.STUDENT_PASSWORD;
  5   | 
  6   | const universityUser = process.env.UNIVERSITY_USERNAME || 'admin@ictuniversity.cm';
  7   | const universityPass = process.env.UNIVERSITY_PASSWORD;
  8   | 
  9   | const recruiterPassword = process.env.RECRUITER_PASSWORD || 'StrongPass123!';
  10  | const recruiterEmail = process.env.RECRUITER_EMAIL || `pw.recruiter.${Date.now()}@mailinator.com`;
  11  | 
  12  | test.describe('Diplomax Backend MVP', () => {
  13  |   test('health endpoint returns 200', async ({ request }) => {
  14  |     const res = await request.get('/healthz');
  15  |     expect(res.status()).toBe(200);
  16  |     const body = await res.json();
  17  |     expect(body.status).toBe('ok');
  18  |   });
  19  | 
  20  |   test('student login succeeds with configured credentials', async ({ request }) => {
  21  |     test.skip(!studentPass, 'STUDENT_PASSWORD not provided');
  22  | 
  23  |     const payload = new URLSearchParams({
  24  |       username: studentUser,
  25  |       password: studentPass,
  26  |     }).toString();
  27  | 
  28  |     const res = await request.post('/v1/auth/login/student', {
  29  |       data: payload,
  30  |       headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  31  |     });
  32  | 
  33  |     expect(res.status(), await res.text()).toBe(200);
  34  |     const body = await res.json();
  35  |     expect(body.access_token).toBeTruthy();
  36  |     expect(body.refresh_token).toBeTruthy();
  37  |     expect(body.role).toBe('student');
  38  |   });
  39  | 
  40  |   test('university login succeeds with configured credentials', async ({ request }) => {
  41  |     test.skip(!universityPass, 'UNIVERSITY_PASSWORD not provided');
  42  | 
  43  |     const payload = new URLSearchParams({
  44  |       username: universityUser,
  45  |       password: universityPass,
  46  |     }).toString();
  47  | 
  48  |     const res = await request.post('/v1/auth/login/university', {
  49  |       data: payload,
  50  |       headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  51  |     });
  52  | 
  53  |     expect(res.status(), await res.text()).toBe(200);
  54  |     const body = await res.json();
  55  |     expect(body.access_token).toBeTruthy();
  56  |     expect(body.refresh_token).toBeTruthy();
  57  |     expect(body.role).toBe('university');
  58  |   });
  59  | 
  60  |   test('recruiter registration endpoint responds correctly', async ({ request }) => {
  61  |     const res = await request.post('/v1/auth/register/recruiter', {
  62  |       data: {
  63  |         company_name: 'Playwright MVP Recruiter',
  64  |         email: recruiterEmail,
  65  |         phone: '+237600000111',
  66  |         password: recruiterPassword,
  67  |       },
  68  |       headers: { 'Content-Type': 'application/json' },
  69  |     });
  70  | 
  71  |     // On first run this should be 200. If email already exists, API returns 409.
  72  |     expect([200, 409], await res.text()).toContain(res.status());
  73  | 
  74  |     if (res.status() === 200) {
  75  |       const body = await res.json();
  76  |       expect(body.access_token).toBeTruthy();
  77  |       expect(body.role).toBe('recruiter');
  78  |     }
  79  |   });
  80  | 
  81  |   test('recruiter login works when credentials are available', async ({ request }) => {
  82  |     const user = process.env.RECRUITER_LOGIN_EMAIL || recruiterEmail;
  83  |     const pass = process.env.RECRUITER_LOGIN_PASSWORD || recruiterPassword;
  84  | 
  85  |     const payload = new URLSearchParams({
  86  |       username: user,
  87  |       password: pass,
  88  |     }).toString();
  89  | 
  90  |     const res = await request.post('/v1/auth/login/recruiter', {
  91  |       data: payload,
  92  |       headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  93  |     });
  94  | 
  95  |     // If recruiter email is new but registration failed, this can be 401.
> 96  |     expect([200, 401], await res.text()).toContain(res.status());
      |                                          ^ Error: {"detail":"Internal server error"}
  97  | 
  98  |     if (res.status() === 200) {
  99  |       const body = await res.json();
  100 |       expect(body.access_token).toBeTruthy();
  101 |       expect(body.role).toBe('recruiter');
  102 |     }
  103 |   });
  104 | });
  105 | 
```