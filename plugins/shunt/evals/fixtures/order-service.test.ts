import { describe, it, expect, beforeEach, jest } from '@jest/globals';
import { OrderService } from '../services/order-service';
import { MockDatabase } from '../test-utils/mock-db';

describe('OrderService', () => {
  let service: OrderService;
  let db: MockDatabase;

  beforeEach(() => {
    db = new MockDatabase();
    service = new OrderService(db);
  });

  describe('createOrder', () => {
    it('should create an order with valid input', async () => {
      const order = await service.createOrder({
        userId: 'user-1',
        items: [{ productId: 'prod-1', quantity: 2 }],
      });
      expect(order.id).toBeDefined();
      expect(order.status).toBe('pending');
    });

    it('should throw on empty items', async () => {
      await expect(
        service.createOrder({ userId: 'user-1', items: [] })
      ).rejects.toThrow('Items cannot be empty');
    });

    it('should validate quantity is positive', async () => {
      await expect(
        service.createOrder({
          userId: 'user-1',
          items: [{ productId: 'prod-1', quantity: -1 }],
        })
      ).rejects.toThrow('Quantity must be positive');
    });
  });

  describe('getOrder', () => {
    it('should return order by id', async () => {
      const created = await service.createOrder({
        userId: 'user-1',
        items: [{ productId: 'prod-1', quantity: 1 }],
      });
      const fetched = await service.getOrder(created.id);
      expect(fetched).toEqual(created);
    });

    it('should return null for non-existent order', async () => {
      const result = await service.getOrder('non-existent');
      expect(result).toBeNull();
    });
  });
});
