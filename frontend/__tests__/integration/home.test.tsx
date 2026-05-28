import React from 'react';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import MockAdapter from 'axios-mock-adapter';
import axios from 'axios';

const mockedUseNavigate = jest.fn();
jest.mock('react-router-dom', () => ({
  ...jest.requireActual('react-router-dom'),
  useNavigate: () => mockedUseNavigate,
  BrowserRouter: ({ children }: { children: React.ReactNode }) => <>{children}</>,
}));

import App from '../../src/App';

const API = 'undefined';

function makePost(i: number) {
  return { _id: `post-id-${i}`, title: `Post Title ${i}`, description: `Desc ${i}`,
    category: ['travel'], image: 'https://example.com/img.jpg',
    author: 'Test', createdAt: new Date().toISOString(), isFeatured: false };
}
function makeFeaturedPost(i: number) { return { ...makePost(i), isFeatured: true }; }

const allPosts      = Array.from({ length: 10 }, (_, i) => makePost(i));
const featuredPosts = Array.from({ length: 5  }, (_, i) => makeFeaturedPost(i));
const latestPosts   = Array.from({ length: 5  }, (_, i) => makePost(i + 10));

let mock: MockAdapter;
beforeAll(() => { mock = new MockAdapter(axios, { onNoMatch: 'passthrough' }); });
beforeEach(() => {
  mock.reset(); mockedUseNavigate.mockClear();
  mock.onGet(`${API}/api/posts`).reply(200, allPosts);
  mock.onGet(`${API}/api/posts/featured`).reply(200, featuredPosts);
  mock.onGet(`${API}/api/posts/latest`).reply(200, latestPosts);
  mock.onGet(new RegExp(`${API}/api/posts/categories/.*`)).reply(200, allPosts);
});
afterAll(() => { mock.restore(); });

describe('Integration Test: Home Route', () => {
  test('Home Route: Verify render of featured post card', async () => {
    render(<App />);
    const featuredPostCard = await screen.findAllByTestId('featuredPostCard', {}, { timeout: 8000 });
    expect(featuredPostCard).toHaveLength(5);
    await userEvent.click(featuredPostCard[0]);
    expect(mockedUseNavigate).toHaveBeenCalledTimes(1);
  });
  test('Home Route: Verify render of post card under All Post section', async () => {
    render(<App />);
    expect(await screen.findAllByTestId('postcard', {}, { timeout: 8000 })).toHaveLength(10);
  });
  test('Home Route: Verify navigation on post card click under All Posts section', async () => {
    render(<App />);
    const allPostCard = await screen.findAllByTestId('postcard', {}, { timeout: 8000 });
    expect(allPostCard).toHaveLength(10);
    await userEvent.click(allPostCard[0]);
    expect(mockedUseNavigate).toHaveBeenCalledTimes(1);
  });
});
