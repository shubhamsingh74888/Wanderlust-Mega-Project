// __tests__/integration/home.test.tsx
// Fixed: axios-mock-adapter intercepts requests at the correct URL.
// Root cause of original failures:
//   - import.meta.env.VITE_API_PATH resolves to "undefined" in Jest
//     (Jest does not process Vite env vars)
//   - So the component calls axios.get("undefined/api/posts")
//   - No mock intercepted that URL → component stayed in skeleton state
//   - findAllByTestId('featuredPostCard') timed out
// Fix: mock exactly "undefined/api/posts" to match what the component calls.

import React from 'react';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import MockAdapter from 'axios-mock-adapter';
import axios from 'axios';

// ── Mock useNavigate ────────────────────────────────────────────────────────
const mockedUseNavigate = jest.fn();
jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useNavigate: () => mockedUseNavigate,
  BrowserRouter: ({ children }: { children: React.ReactNode }) => <>{children}</>,
}));

import App from '../../src/App';

// In Jest, import.meta.env.VITE_API_PATH === undefined (string "undefined")
const API = 'undefined';

// ── Test data helpers ───────────────────────────────────────────────────────
function makePost(i: number) {
  return {
    _id: `post-id-${i}`,
    title: `Post Title ${i}`,
    description: `Description ${i}`,
    category: ['travel'],
    image: 'https://example.com/image.jpg',
    author: 'Test Author',
    createdAt: new Date().toISOString(),
    isFeatured: false,
  };
}

function makeFeaturedPost(i: number) {
  return { ...makePost(i), isFeatured: true };
}

const allPosts      = Array.from({ length: 10 }, (_, i) => makePost(i));
const featuredPosts = Array.from({ length: 5  }, (_, i) => makeFeaturedPost(i));
const latestPosts   = Array.from({ length: 5  }, (_, i) => makePost(i + 10));

// ── Axios mock setup ────────────────────────────────────────────────────────
let mock: MockAdapter;

beforeAll(() => {
  mock = new MockAdapter(axios, { onNoMatch: 'passthrough' });
});

beforeEach(() => {
  mock.reset();
  mockedUseNavigate.mockClear();

  mock.onGet(`${API}/api/posts`).reply(200, allPosts);
  mock.onGet(`${API}/api/posts/featured`).reply(200, featuredPosts);
  mock.onGet(`${API}/api/posts/latest`).reply(200, latestPosts);
  mock.onGet(new RegExp(`${API}/api/posts/categories/.*`)).reply(200, allPosts);
});

afterAll(() => {
  mock.restore();
});

// ── Tests ───────────────────────────────────────────────────────────────────
describe('Integration Test: Home Route', () => {

  test('Home Route: Verify render of featured post card', async () => {
    //ARRANGE
    render(<App />);
    //ACT
    //ASSERT
    const featuredPostCard = await screen.findAllByTestId('featuredPostCard', {}, { timeout: 8000 });
    expect(featuredPostCard).toHaveLength(5);
    await userEvent.click(featuredPostCard[0]);
    expect(mockedUseNavigate).toHaveBeenCalledTimes(1);
  });

  test('Home Route: Verify render of post card under All Post section', async () => {
    //ARRANGE
    render(<App />);
    //ACT
    //ASSERT
    expect(await screen.findAllByTestId('postcard', {}, { timeout: 8000 })).toHaveLength(10);
  });

  test('Home Route: Verify navigation on post card click under All Posts section', async () => {
    //ARRANGE
    render(<App />);
    //ACT
    //ASSERT
    const allPostCard = await screen.findAllByTestId('postcard', {}, { timeout: 8000 });
    expect(allPostCard).toHaveLength(10);
    /**
     * INFO:
     * Clicking a post card triggers useNavigate() with the post slug.
     * We verify it was called exactly once.
     */
    await userEvent.click(allPostCard[0]);
    expect(mockedUseNavigate).toHaveBeenCalledTimes(1);
  });

});
