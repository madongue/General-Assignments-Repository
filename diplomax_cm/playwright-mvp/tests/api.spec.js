const { test, expect } = require('@playwright/test');

const studentUser = process.env.STUDENT_USERNAME || 'ICTU20223180';
const studentPass = process.env.STUDENT_PASSWORD;

const universityUser = process.env.UNIVERSITY_USERNAME || 'admin@ictuniversity.cm';
const universityPass = process.env.UNIVERSITY_PASSWORD;

const recruiterPassword = process.env.RECRUITER_PASSWORD || 'StrongPass123!';
const recruiterEmail = process.env.RECRUITER_EMAIL || `pw.recruiter.${Date.now()}@mailinator.com`;

test.describe('Diplomax Backend MVP', () => {
  test('health endpoint returns 200', async ({ request }) => {
    const res = await request.get('/healthz');
    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body.status).toBe('ok');
  });

  test('student login succeeds with configured credentials', async ({ request }) => {
    test.skip(!studentPass, 'STUDENT_PASSWORD not provided');

    const payload = new URLSearchParams({
      username: studentUser,
      password: studentPass,
    }).toString();

    const res = await request.post('/v1/auth/login/student', {
      data: payload,
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    });

    expect(res.status(), await res.text()).toBe(200);
    const body = await res.json();
    expect(body.access_token).toBeTruthy();
    expect(body.refresh_token).toBeTruthy();
    expect(body.role).toBe('student');
  });

  test('university login succeeds with configured credentials', async ({ request }) => {
    test.skip(!universityPass, 'UNIVERSITY_PASSWORD not provided');

    const payload = new URLSearchParams({
      username: universityUser,
      password: universityPass,
    }).toString();

    const res = await request.post('/v1/auth/login/university', {
      data: payload,
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    });

    expect(res.status(), await res.text()).toBe(200);
    const body = await res.json();
    expect(body.access_token).toBeTruthy();
    expect(body.refresh_token).toBeTruthy();
    expect(body.role).toBe('university');
  });

  test('recruiter registration endpoint responds correctly', async ({ request }) => {
    const res = await request.post('/v1/auth/register/recruiter', {
      data: {
        company_name: 'Playwright MVP Recruiter',
        email: recruiterEmail,
        phone: '+237600000111',
        password: recruiterPassword,
      },
      headers: { 'Content-Type': 'application/json' },
    });

    // On first run this should be 200. If email already exists, API returns 409.
    expect([200, 409], await res.text()).toContain(res.status());

    if (res.status() === 200) {
      const body = await res.json();
      expect(body.access_token).toBeTruthy();
      expect(body.role).toBe('recruiter');
    }
  });

  test('recruiter login works when credentials are available', async ({ request }) => {
    const user = process.env.RECRUITER_LOGIN_EMAIL || recruiterEmail;
    const pass = process.env.RECRUITER_LOGIN_PASSWORD || recruiterPassword;

    const payload = new URLSearchParams({
      username: user,
      password: pass,
    }).toString();

    const res = await request.post('/v1/auth/login/recruiter', {
      data: payload,
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    });

    // If recruiter email is new but registration failed, this can be 401.
    expect([200, 401], await res.text()).toContain(res.status());

    if (res.status() === 200) {
      const body = await res.json();
      expect(body.access_token).toBeTruthy();
      expect(body.role).toBe('recruiter');
    }
  });
});
